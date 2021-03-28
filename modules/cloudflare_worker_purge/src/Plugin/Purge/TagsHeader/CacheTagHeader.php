<?php

namespace Drupal\cloudflare_worker_purge\Plugin\Purge\TagsHeader;

use Drupal\purge\Plugin\Purge\TagsHeader\TagsHeaderBase;
use Drupal\purge\Plugin\Purge\TagsHeader\TagsHeaderInterface;

/**
 * Adds an `X-Cache-Tag` header to the response.
 *
 * The `Cache-Tag` header is swallowed by Cloudflare before the response reaches
 * the Worker. To prevent this from happening the header is renamed to
 * `X-Cache-Tag` but with the same format.
 *
 * @PurgeTagsHeader(
 *   id = "cloudflare_worker",
 *   header_name = "X-Cache-Tag",
 * )
 */
class CacheTagHeader extends TagsHeaderBase implements TagsHeaderInterface {

  /**
   * {@inheritdoc}
   */
  public function getValue(array $tags) {
    return implode(',', $tags);
  }

}
