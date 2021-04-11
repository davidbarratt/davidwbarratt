<?php

namespace Drupal\cloudflare_worker_purge\Form;

use Drupal\Core\Form\FormStateInterface;
use Drupal\purge_ui\Form\PurgerConfigFormBase;

/**
 * Cloudflare Worker Purge Configuration Form.
 */
class CloudflareWorkerPurgeForm extends PurgerConfigFormBase {

  /**
   * Configuration Name.
   *
   * @var string
   */
  private const CONFIG_NAME = 'cloudflare_worker_purge.settings';

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'cloudflare_worker_purge.purger_configuration_form';
  }

  /**
   * {@inheritdoc}
   */
  protected function getEditableConfigNames() {
    return [
      self::CONFIG_NAME,
    ];
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config(self::CONFIG_NAME);
    $form['url'] = [
      '#title' => $this->t('URL'),
      '#type' => 'url',
      '#default_value' => $config->get('url'),
      '#description' => $this->t('The purger with make a request to the URL in the same format as the <a href="@cache_api">Purge Cache API</a> with the addition of a <code>CF-Zone</code> header that contains the zone id.', [
        "@cache_api" => 'https://api.cloudflare.com/#zone-purge-files-by-cache-tags,-host-or-prefix',
      ]),
    ];

    return parent::buildForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function submitFormSuccess(array &$form, FormStateInterface $form_state) {
    $this->config(self::CONFIG_NAME)
      ->set('url', $form_state->getValue('url'))
      ->save();
  }

}
