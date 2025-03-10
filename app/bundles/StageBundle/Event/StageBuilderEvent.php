<?php

namespace Mautic\StageBundle\Event;

use Symfony\Component\Process\Exception\InvalidArgumentException;
use Symfony\Contracts\EventDispatcher\Event;
use Symfony\Contracts\Translation\TranslatorInterface;

class StageBuilderEvent extends Event
{
    private array $actions = [];

    public function __construct(
        private TranslatorInterface $translator,
    ) {
    }

    /**
     * Adds an action to the list of available .
     *
     * @param string $key    - a unique identifier; it is recommended that it be namespaced i.e. lead.action
     * @param array  $action - can contain the following keys:
     *                       'label'           => (required) what to display in the list
     *                       'description'     => (optional) short description of event
     *                       'template'        => (optional) template to use for the action's HTML in the stage builder
     *                       i.e AcmeMyBundle:StageAction:theaction.html.twig
     *                       'formType'        => (optional) name of the form type SERVICE for the action; will use a default form with stage change only
     *                       'formTypeOptions' => (optional) array of options to pass to formType
     *                       'callback'        => (optional) callback function that will be passed when the action is triggered; return true to
     *                       change the configured stages or false to ignore the action
     *                       The callback function can receive the following arguments by name (via ReflectionMethod::invokeArgs())
     *                       Mautic\LeadBundle\Entity\Lead $lead
     *                       $eventDetails - variable sent from firing function to call back function
     *                       array $action = array(
     *                       'id' => int
     *                       'type' => string
     *                       'name' => string
     *                       'properties' => array()
     *                       )
     *
     * @throws InvalidArgumentException
     */
    public function addAction($key, array $action): void
    {
        if (array_key_exists($key, $this->actions)) {
            throw new InvalidArgumentException("The key, '$key' is already used by another action. Please use a different key.");
        }

        // check for required keys and that given functions are callable
        $this->verifyComponent(
            ['group', 'label'],
            ['callback'],
            $action
        );

        // translate the label and group
        $action['label'] = $this->translator->trans($action['label']);
        $action['group'] = $this->translator->trans($action['group']);

        $this->actions[$key] = $action;
    }

    /**
     * Get actions.
     *
     * @return array
     */
    public function getActions()
    {
        uasort($this->actions, fn ($a, $b): int => strnatcasecmp(
            $a['label'], $b['label']));

        return $this->actions;
    }

    /**
     * Gets a list of actions supported by the choice form field.
     */
    public function getActionList(): array
    {
        $list    = [];
        $actions = $this->getActions();
        foreach ($actions as $k => $a) {
            $list[$k] = $a['label'];
        }

        return $list;
    }

    /**
     * @return mixed[]
     */
    public function getActionChoices(): array
    {
        $choices = [];
        $this->getActions();
        foreach ($this->actions as $k => $c) {
            $choices[$c['group']][$k] = $c['label'];
        }

        return $choices;
    }

    /**
     * @throws InvalidArgumentException
     */
    private function verifyComponent(array $keys, array $methods, array $component): void
    {
        foreach ($keys as $k) {
            if (!array_key_exists($k, $component)) {
                throw new InvalidArgumentException("The key, '$k' is missing.");
            }
        }

        foreach ($methods as $m) {
            if (isset($component[$m]) && !is_callable($component[$m], true)) {
                throw new InvalidArgumentException($component[$m].' is not callable.  Please ensure that it exists and that it is a fully qualified namespace.');
            }
        }
    }
}
