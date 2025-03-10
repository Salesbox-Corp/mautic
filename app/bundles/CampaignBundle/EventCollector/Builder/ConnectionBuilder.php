<?php

namespace Mautic\CampaignBundle\EventCollector\Builder;

use Mautic\CampaignBundle\Entity\Event;

class ConnectionBuilder
{
    private static array $eventTypes = [];

    private static array $connectionRestrictions = ['anchor' => []];

    /**
     * Used by JS/JsPlumb to restrict how events can be associated to each other in the UI.
     *
     * @return array
     */
    public static function buildRestrictionsArray(array $events)
    {
        // Reset restrictions
        self::$connectionRestrictions = ['anchor' => []];

        // Build the restrictions
        self::$eventTypes = array_fill_keys(array_keys($events), []);
        foreach ($events as $eventType => $typeEvents) {
            foreach ($typeEvents as $key => $event) {
                self::addTypeConnection($eventType, $key, $event);
            }
        }

        return self::$connectionRestrictions;
    }

    /**
     * @param string $eventType
     * @param string $key
     */
    private static function addTypeConnection($eventType, $key, array $event): void
    {
        if (!isset(self::$connectionRestrictions[$key])) {
            self::$connectionRestrictions[$key] = [
                'source' => self::$eventTypes,
                'target' => self::$eventTypes,
            ];
        }

        if (!isset(self::$connectionRestrictions[$key])) {
            self::$connectionRestrictions['anchor'][$key] = [];
        }

        if (isset($event['connectionRestrictions'])) {
            foreach ($event['connectionRestrictions'] as $restrictionType => $restrictions) {
                self::addRestriction($key, $restrictionType, $restrictions);
            }
        }

        self::addDeprecatedAnchorRestrictions($eventType, $key, $event);
    }

    /**
     * @param string $key
     * @param string $restrictionType
     */
    private static function addRestriction($key, $restrictionType, array $restrictions): void
    {
        switch ($restrictionType) {
            case 'source':
            case 'target':
                foreach ($restrictions as $groupType => $groupRestrictions) {
                    self::$connectionRestrictions[$key][$restrictionType][$groupType] += $groupRestrictions;
                }
                break;
            case 'anchor':
                foreach ($restrictions as $anchor) {
                    [$group, $anchor]                                               = explode('.', $anchor);
                    self::$connectionRestrictions[$restrictionType][$group][$key][] = $anchor;
                }

                break;
        }
    }

    /**
     * @deprecated 2.6.0 to be removed in 3.0; BC support
     *
     * @param string $eventType
     * @param string $key
     */
    private static function addDeprecatedAnchorRestrictions($eventType, $key, array $event): void
    {
        switch ($eventType) {
            case Event::TYPE_DECISION:
                if (isset($event['associatedActions'])) {
                    self::$connectionRestrictions[$key]['target']['action'] += $event['associatedActions'];
                }
                break;
            case Event::TYPE_ACTION:
                if (isset($event['associatedDecisions'])) {
                    self::$connectionRestrictions[$key]['source']['decision'] += $event['associatedDecisions'];
                }
                break;
        }

        if (isset($event['anchorRestrictions'])) {
            foreach ($event['anchorRestrictions'] as $restriction) {
                [$group, $anchor]                                       = explode('.', $restriction);
                self::$connectionRestrictions['anchor'][$key][$group][] = $anchor;
            }
        }
    }
}
