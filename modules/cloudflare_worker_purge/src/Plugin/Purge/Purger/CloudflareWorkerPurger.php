<?php

namespace Drupal\cloudflare_worker_purge\Plugin\Purge\Purger;

use CloudFlarePhpSdk\ApiEndpoints\CloudFlareAPI;
use Drupal\Core\Config\Config;
use Drupal\purge\Plugin\Purge\Invalidation\InvalidationInterface;
use Drupal\purge\Plugin\Purge\Purger\PurgerBase;
use Symfony\Component\DependencyInjection\ContainerInterface;
use GuzzleHttp\ClientInterface;
use GuzzleHttp\Exception\ClientException;
use GuzzleHttp\Promise\Utils;

/**
 * Cloudflare Worker purger.
 *
 * @PurgePurger(
 *   id = "cloudflare_worker",
 *   label = @Translation("Cloudflare Worker"),
 *   description = @Translation("Purger for Cloudflare Worker."),
 *   types = {"tag"},
 *   multi_instance = FALSE,
 * )
 */
class CloudflareWorkerPurger extends PurgerBase {

  /**
   * HTTP Client.
   *
   * @var GuzzleHttp\ClientInterface
   */
  protected $client;

  /**
   * Cloudflare Config.
   *
   * @var Drupal\Core\Config\Config
   */
  protected $config;

  /**
   * {@inheritdoc}
   */
  public function __construct(
    array $configuration,
    $plugin_id,
    $plugin_definition,
    Config $config,
    ClientInterface $client
  ) {
    parent::__construct($configuration, $plugin_id, $plugin_definition);

    $this->config = $config;
    $this->client = $client;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container, array $configuration, $plugin_id, $plugin_definition) {
    return new static(
      $configuration,
      $plugin_id,
      $plugin_definition,
      $container->get('config.factory')->get('cloudflare.settings'),
      $container->get('http_client')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function hasRuntimeMeasurement() {
    return TRUE;
  }

  /**
   * {@inheritdoc}
   */
  public function invalidate(array $invalidations) {
    if (empty($invalidations)) {
      return;
    }

    // Get the unique tags to purge.
    $tags = array_unique(array_map(function ($invalidation) {
      return $invalidation->getExpression();
    }, $invalidations));

    $promises = array_map(function ($chunk) {
      // @todo Make the URL configurable!
      return $this->client->getAsync('https://davidwbarratt.com/.cloudflare/purge', [
        'headers' => [
          'CF-Zone' => $this->config->get('zone_id'),
          'X-Auth-Email' => $this->config->get('email'),
          'X-Auth-Key' => $this->config->get('apikey'),
        ],
        'json' => [
          'tags' => $chunk,
        ],
      ])->then(function ($response) use ($chunk) {
        return $chunk;
      }, function (ClientException $e) {
        // None of the tags were resolved.
        return [];
      });
    }, array_chunk($tags, CloudFlareAPI::MAX_TAG_PURGES_PER_REQUEST));

    // Execute the promises.
    $resolved = array_merge(...Utils::unwrap($promises));

    // Set the state of each invalidation.
    foreach ($invalidations as $invalidation) {
      if (in_array($invalidation->getExpression(), $resolved)) {
        $invalidation->setState(InvalidationInterface::SUCCEEDED);
      }
      else {
        $invalidation->setState(InvalidationInterface::FAILED);
      }
    }
  }

}
