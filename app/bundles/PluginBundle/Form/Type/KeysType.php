<?php

namespace Mautic\PluginBundle\Form\Type;

use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\Extension\Core\Type\PasswordType;
use Symfony\Component\Form\Extension\Core\Type\TextType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolver;
use Symfony\Component\Validator\Constraints\Callback;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

/**
 * @extends AbstractType<array<mixed>>
 */
class KeysType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $object       = $options['integration_object'];
        $secretKeys   = $object->getSecretKeys();
        $requiredKeys = $object->getRequiredKeyFields();

        foreach ($options['integration_keys'] as $key => $label) {
            $isSecret = in_array($key, $secretKeys);
            $required = (isset($requiredKeys[$key]));

            // Password fields are going to be blank even if a value exists so only require if a password is not already saved
            if ($isSecret && !empty($options['data'][$key])) {
                $required = false;
            }

            $constraints = ($required)
                ? [
                    new Callback(
                        function ($validateMe, ExecutionContextInterface $context) use ($options): void {
                            if (empty($validateMe) && !empty($options['is_published'])) {
                                $context->buildViolation('mautic.core.value.required')->addViolation();
                            }
                        }
                    ),
                ] : [];

            $type = ($isSecret) ? PasswordType::class : TextType::class;

            $builder->add(
                $key,
                $type,
                [
                    'label'      => $label,
                    'label_attr' => ['class' => 'control-label'],
                    'attr'       => [
                        'class'        => 'form-control',
                        'placeholder'  => (PasswordType::class === $type) ? '**************' : '',
                        'autocomplete' => 'off',
                    ],
                    'required'       => $required,
                    'constraints'    => $constraints,
                    'error_bubbling' => false,
                ]
            );
        }
        $object->appendToForm($builder, $options['data'], 'keys');
    }

    public function configureOptions(OptionsResolver $resolver): void
    {
        $resolver->setRequired(['integration_object', 'integration_keys']);
        $resolver->setDefined(['secret_keys']);
        $resolver->setDefaults(['secret_keys' => [], 'is_published' => true]);
    }

    public function getBlockPrefix(): string
    {
        return 'integration_keys';
    }
}
