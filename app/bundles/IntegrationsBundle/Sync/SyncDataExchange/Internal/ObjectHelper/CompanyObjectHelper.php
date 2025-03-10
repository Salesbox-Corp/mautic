<?php

declare(strict_types=1);

namespace Mautic\IntegrationsBundle\Sync\SyncDataExchange\Internal\ObjectHelper;

use Doctrine\DBAL\ArrayParameterType;
use Doctrine\DBAL\Connection;
use Mautic\IntegrationsBundle\Entity\ObjectMapping;
use Mautic\IntegrationsBundle\Sync\DAO\Mapping\UpdatedObjectMappingDAO;
use Mautic\IntegrationsBundle\Sync\DAO\Sync\Order\FieldDAO;
use Mautic\IntegrationsBundle\Sync\DAO\Sync\Order\ObjectChangeDAO;
use Mautic\IntegrationsBundle\Sync\Logger\DebugLogger;
use Mautic\IntegrationsBundle\Sync\SyncDataExchange\MauticSyncDataExchange;
use Mautic\LeadBundle\Entity\Company;
use Mautic\LeadBundle\Entity\CompanyRepository;
use Mautic\LeadBundle\Field\FieldsWithUniqueIdentifier;
use Mautic\LeadBundle\Model\CompanyModel;

class CompanyObjectHelper implements ObjectHelperInterface
{
    /**
     * @var string[]|null
     */
    private ?array $uniqueIdentifierFields = null;

    /**
     * @var array<string,Company>
     */
    private array $companiesCreated = [];

    public function __construct(
        private CompanyModel $model,
        private CompanyRepository $repository,
        private Connection $connection,
        private FieldsWithUniqueIdentifier $fieldsWithUniqueIdentifier,
    ) {
    }

    /**
     * @param ObjectChangeDAO[] $objects
     *
     * @return ObjectMapping[]
     */
    public function create(array $objects): array
    {
        $objectMappings = [];
        foreach ($objects as $object) {
            $fields  = $object->getFields();
            $company = $this->getCompanyEntity($fields);

            foreach ($fields as $field) {
                $company->addUpdatedField($field->getName(), $field->getValue()->getNormalizedValue());
            }

            $this->model->saveEntity($company);

            DebugLogger::log(
                MauticSyncDataExchange::NAME,
                sprintf(
                    'Created company ID %d',
                    $company->getId()
                ),
                self::class.':'.__FUNCTION__
            );

            $objectMapping = new ObjectMapping();
            $objectMapping->setLastSyncDate($object->getChangeDateTime())
                ->setIntegration($object->getIntegration())
                ->setIntegrationObjectName($object->getMappedObject())
                ->setIntegrationObjectId($object->getMappedObjectId())
                ->setInternalObjectName(MauticSyncDataExchange::OBJECT_COMPANY)
                ->setInternalObjectId($company->getId());
            $objectMappings[] = $objectMapping;
        }

        // Detach to free RAM after all companies are processed in case there are duplicates in the same batch
        foreach ($this->companiesCreated as $company) {
            $this->repository->detachEntity($company);
        }

        // Reset companies created for the next batch
        $this->companiesCreated = [];

        return $objectMappings;
    }

    /**
     * @param ObjectChangeDAO[] $objects
     *
     * @return UpdatedObjectMappingDAO[]
     */
    public function update(array $ids, array $objects): array
    {
        $updatedMappedObjects = [];

        if (!$ids) {
            return $updatedMappedObjects;
        }

        /** @var Company[] $companies */
        $companies = $this->model->getEntities(['ids' => $ids]);
        DebugLogger::log(
            MauticSyncDataExchange::NAME,
            sprintf(
                'Found %d companies to update with ids %s',
                count($companies),
                implode(', ', $ids)
            ),
            self::class.':'.__FUNCTION__
        );

        foreach ($companies as $company) {
            /** @var ObjectChangeDAO $changedObject */
            $changedObject = $objects[$company->getId()];
            $fields        = $changedObject->getFields();

            foreach ($fields as $field) {
                $company->addUpdatedField($field->getName(), $field->getValue()->getNormalizedValue());
            }

            $this->model->saveEntity($company);
            $this->repository->detachEntity($company);

            DebugLogger::log(
                MauticSyncDataExchange::NAME,
                sprintf(
                    'Updated company ID %d',
                    $company->getId()
                ),
                self::class.':'.__FUNCTION__
            );

            // Integration name and ID are stored in the change's mappedObject/mappedObjectId
            $updatedMappedObjects[] = new UpdatedObjectMappingDAO(
                $changedObject->getIntegration(),
                $changedObject->getMappedObject(),
                $changedObject->getMappedObjectId(),
                $changedObject->getChangeDateTime()
            );
        }

        return $updatedMappedObjects;
    }

    /**
     * Unfortunately the CompanyRepository doesn't give us what we need so we have to write our own queries.
     *
     * @param int $start
     * @param int $limit
     */
    public function findObjectsBetweenDates(\DateTimeInterface $from, \DateTimeInterface $to, $start, $limit): array
    {
        $qb = $this->connection->createQueryBuilder();
        $qb->select('*')
            ->from(MAUTIC_TABLE_PREFIX.'companies', 'c')
            ->where(
                $qb->expr()->or(
                    $qb->expr()->and(
                        $qb->expr()->isNotNull('c.date_modified'),
                        $qb->expr()->comparison('c.date_modified', 'BETWEEN', ':dateFrom and :dateTo')
                    ),
                    $qb->expr()->and(
                        $qb->expr()->isNull('c.date_modified'),
                        $qb->expr()->comparison('c.date_added', 'BETWEEN', ':dateFrom and :dateTo')
                    )
                )
            )
            ->setParameter('dateFrom', $from->format('Y-m-d H:i:s'))
            ->setParameter('dateTo', $to->format('Y-m-d H:i:s'))
            ->setFirstResult($start)
            ->setMaxResults($limit);

        return $qb->executeQuery()->fetchAllAssociative();
    }

    public function findObjectsByIds(array $ids): array
    {
        if (!count($ids)) {
            return [];
        }

        $qb = $this->connection->createQueryBuilder();
        $qb->select('*')
            ->from(MAUTIC_TABLE_PREFIX.'companies', 'c')
            ->where(
                $qb->expr()->in('id', $ids)
            );

        return $qb->executeQuery()->fetchAllAssociative();
    }

    public function findObjectsByFieldValues(array $fields): array
    {
        $q = $this->connection->createQueryBuilder()
            ->select('c.id')
            ->from(MAUTIC_TABLE_PREFIX.'companies', 'c');

        foreach ($fields as $col => $val) {
            // Use andWhere because Mautic treats conflicting unique identifiers as different objects
            $q->{$this->repository->getUniqueIdentifiersWherePart()}("c.$col = :".$col)
                ->setParameter($col, $val);
        }

        return $q->executeQuery()->fetchAllAssociative();
    }

    public function findOwnerIds(array $objectIds): array
    {
        if (empty($objectIds)) {
            return [];
        }

        $qb = $this->connection->createQueryBuilder();
        $qb->select('c.owner_id, c.id');
        $qb->from(MAUTIC_TABLE_PREFIX.'companies', 'c');
        $qb->where('c.owner_id IS NOT NULL');
        $qb->andWhere('c.id IN (:objectIds)');
        $qb->setParameter('objectIds', $objectIds, ArrayParameterType::INTEGER);

        return $qb->executeQuery()->fetchAllAssociative();
    }

    public function findObjectById(int $id): ?Company
    {
        return $this->repository->getEntity($id);
    }

    public function setFieldValues(Company $company): void
    {
        $this->model->setFieldValues($company, []);
    }

    /**
     * @return string[]
     */
    private function getUniqueIdentifierFields(): array
    {
        if (null === $this->uniqueIdentifierFields) {
            $uniqueIdentifierFields       = $this->fieldsWithUniqueIdentifier->getFieldsWithUniqueIdentifier(['object' => MauticSyncDataExchange::OBJECT_COMPANY]);
            $this->uniqueIdentifierFields = array_keys($uniqueIdentifierFields);
        }

        return $this->uniqueIdentifierFields;
    }

    /**
     * @param FieldDAO[] $fields
     */
    private function getCompanyEntity(array $fields): Company
    {
        $uniqueIdentifierFields = $this->getUniqueIdentifierFields();

        // Create a key based on the concatenation of unique identifier values
        $companyKey = '';
        foreach ($uniqueIdentifierFields as $uniqueIdentifierField) {
            if (isset($fields[$uniqueIdentifierField])) {
                $companyKey .= strtolower($fields[$uniqueIdentifierField]->getValue()->getNormalizedValue());
            }
        }

        // Check if a company with matching values was created in the same batch as another
        if (!empty($companyKey) && isset($this->companiesCreated[$companyKey])) {
            return $this->companiesCreated[$companyKey];
        }

        // Create a new company but ensure a unique key
        $companyKey = $companyKey ?: uniqid();

        return $this->companiesCreated[$companyKey] = new Company();
    }
}
