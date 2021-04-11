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
use Psr\Log\LoggerInterface;

/**
 * Cloudflare Worker purger.
 *
 * @PurgePurger(
 *   id = "cloudflare_worker",
 *   label = @Translation("Cloudflare Worker"),
 *   description = @Translation("Purger for Cloudflare Worker."),
 *   types = {"tag"},
 *   multi_instance = FALSE,
 *   configform = "\Drupal\cloudflare_worker_purge\Form\CloudflareWorkerPurgeForm",
 * )
 */
class CloudflareWorkerPurger extends PurgerBase {

  /**
   * HTTP Client.
   *
   * @var \GuzzleHttp\ClientInterface
   */
  protected $client;

  /**
   * Cloudflare Worker Purge Config.
   *
   * @var \Drupal\Core\Config\Config
   */
  protected $config;

  /**
   * Cloudflare Config.
   *
   * @var \Drupal\Core\Config\Config
   */
  protected $cloudflareConfig;

  /**
   * A logger instance.
   *
   * @var \Psr\Log\LoggerInterface
   */
  protected $logger;

  /**
   * {@inheritdoc}
   */
  public function __construct(
    array $configuration,
    $plugin_id,
    $plugin_definition,
    Config $cloudflareConfig,
    Config $config,
    ClientInterface $client,
    LoggerInterface $logger
  ) {
    parent::__construct($configuration, $plugin_id, $plugin_definition);

    $this->cloudflareConfig = $cloudflareConfig;
    $this->config = $config;
    $this->client = $client;
    $this->logger = $logger;
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
      $container->get('config.factory')->get('cloudflare_worker_purge.settings'),
      $container->get('http_client'),
      $container->get('logger.factory')->get('cloudflare')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function getIdealConditionsLimit() {
    return CloudFlareAPI::MAX_TAG_PURGES_PER_REQUEST * 10;
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
    $url = $this->config->get('url');

    if (empty($url)) {
      $this->logger->error('Purge URL not set');

      // Set the state of each invalidation.
      foreach ($invalidations as $invalidation) {
        $invalidation->setState(InvalidationInterface::FAILED);
      }

      return;
    }

    if (empty($invalidations)) {
      return;
    }

    // Get the unique tags to purge.
    $tags = array_unique(array_map(function ($invalidation) {
      return $invalidation->getExpression();
    }, $invalidations));

    $promises = array_map(function ($chunk) {
      return $this->client->postAsync($url, [
        'headers' => [
          'CF-Zone' => $this->cloudflareConfig->get('zone_id'),
          'X-Auth-Email' => $this->cloudflareConfig->get('email'),
          'X-Auth-Key' => $this->cloudflareConfig->get('apikey'),
        ],
        'json' => [
          'tags' => $chunk,
        ],
      ])->then(function ($response) use ($chunk) {
        return $chunk;
      }, function (ClientException $e) {
        $this->logger->error($e->getMessage());

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
