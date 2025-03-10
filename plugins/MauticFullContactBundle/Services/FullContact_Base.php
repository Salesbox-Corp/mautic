<?php

namespace MauticPlugin\MauticFullContactBundle\Services;

use MauticPlugin\MauticFullContactBundle\Exception\NoCreditException;
use MauticPlugin\MauticFullContactBundle\Exception\NotImplementedException;

/**
 * This class handles the actually HTTP request to the FullContact endpoint.
 *
 * @author   Keith Casey <contrib@caseysoftware.com>
 * @license  http://www.apache.org/licenses/LICENSE-2.0 Apache
 */
class FullContact_Base
{
    public const REQUEST_LATENCY = 0.2;

    public const USER_AGENT      = 'caseysoftware/fullcontact-php-0.9.0';

    private \DateTime $_next_req_time;

    //    protected $_baseUri = 'https://requestbin.fullcontact.com/1ailj6d1?';
    protected $_baseUri     = 'https://api.fullcontact.com/';

    protected $_version     = 'v2';

    protected $_resourceUri = '';

    protected $_webhookUrl;

    protected $_webhookId;

    protected $_webhookJson      = false;

    protected $_supportedMethods = [];

    public $response_obj;

    public $response_code;

    public $response_json;

    /**
     * Slow down calls to the FullContact API if needed.
     */
    private function _wait_for_rate_limit(): void
    {
        $now = new \DateTime();
        if ($this->_next_req_time->getTimestamp() > $now->getTimestamp()) {
            $t = $this->_next_req_time->getTimestamp() - $now->getTimestamp();
            sleep($t);
        }
    }

    /**
     * @param mixed[] $hdr
     */
    private function _update_rate_limit($hdr): void
    {
        $remaining            = (float) $hdr['X-Rate-Limit-Remaining'];
        $reset                = (float) $hdr['X-Rate-Limit-Reset'];
        $spacing              = $reset / (1.0 + $remaining);
        $delay                = $spacing - self::REQUEST_LATENCY;
        $this->_next_req_time = new \DateTime('now + '.$delay.' seconds');
    }

    /**
     * The base constructor Sets the API key available from here:
     * http://fullcontact.com/getkey.
     *
     * @param string $_apiKey
     */
    public function __construct(
        protected $_apiKey,
    ) {
        $this->_next_req_time = new \DateTime('@0');
    }

    /**
     * This sets the webhook url for all requests made for this service
     * instance. To unset, just use setWebhookUrl(null).
     *
     * @author  David Boskovic <me@david.gs> @dboskovic
     *
     * @param string $url
     * @param string $id
     * @param bool   $json
     *
     * @return object
     */
    public function setWebhookUrl($url, $id = null, $json = false)
    {
        $this->_webhookUrl  = $url;
        $this->_webhookId   = $id;
        $this->_webhookJson = $json;

        return $this;
    }

    /**
     * This is a pretty close copy of my work on the Contactually PHP library
     *   available here: http://github.com/caseysoftware/contactually-php.
     *
     * @author  Keith Casey <contrib@caseysoftware.com>
     * @author  David Boskovic <me@david.gs> @dboskovic
     *
     * @param array $params
     * @param array $postData
     *
     * @return object
     *
     * @throws NoCreditException
     * @throws NotImplementedException
     */
    protected function _execute($params = [], $postData = null)
    {
        if (null === $postData && !in_array($params['method'], $this->_supportedMethods, true)) {
            throw new NotImplementedException(self::class.' does not support the ['.$params['method'].'] method');
        }

        if (array_key_exists('method', $params)) {
            unset($params['method']);
        }

        $this->_wait_for_rate_limit();

        $params['apiKey'] = $this->_apiKey;

        if ($this->_webhookUrl) {
            $params['webhookUrl'] = $this->_webhookUrl;
        }

        if ($this->_webhookId) {
            $params['webhookId'] = $this->_webhookId;
        }

        if ($this->_webhookJson) {
            $params['webhookBody'] = 'json';
        }

        $fullUrl = $this->_baseUri.$this->_version.$this->_resourceUri.
            '?'.http_build_query($params);

        // open connection
        $connection = curl_init($fullUrl);
        curl_setopt($connection, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($connection, CURLOPT_USERAGENT, self::USER_AGENT);
        curl_setopt($connection, CURLOPT_HEADER, true); // return HTTP headers with response

        if (null !== $postData) {
            curl_setopt($connection, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
            curl_setopt($connection, CURLOPT_POSTFIELDS, json_encode($postData, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
            curl_setopt($connection, CURLOPT_POST, true);
        }

        // execute request
        $resp = curl_exec($connection);

        [$response_headers, $this->response_json] = explode("\r\n\r\n", $resp, 2);
        // $response_headers now has a string of the HTTP headers
        // $response_json is the body of the HTTP response

        $headers = [];

        foreach (explode("\r\n", $response_headers) as $i => $line) {
            if (0 === $i) {
                $headers['http_code'] = $line;
            } else {
                [$key, $value]     = explode(': ', $line);
                $headers[$key]     = $value;
            }
        }

        $this->response_code = curl_getinfo($connection, CURLINFO_HTTP_CODE);
        $this->response_obj  = json_decode($this->response_json);

        if ('403' === $this->response_code) {
            throw new NoCreditException($this->response_obj->message);
        } else {
            if ('200' === $this->response_code) {
                $this->_update_rate_limit($headers);
            }
        }

        return $this->response_obj;
    }
}
