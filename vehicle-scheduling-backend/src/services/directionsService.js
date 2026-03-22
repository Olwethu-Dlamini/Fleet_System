// ============================================
// FILE: src/services/directionsService.js
// PURPOSE: Google Routes API v2 proxy — fetches directions, polyline, ETA, distance
// Requirements: GPS-01
// ============================================

const logger = require('../config/logger').child({ service: 'directionsService' });

/**
 * Fetch driving directions from Google Routes API v2.
 *
 * @param {number} originLat
 * @param {number} originLng
 * @param {number} destLat
 * @param {number} destLng
 * @returns {Promise<{
 *   encoded_polyline: string,
 *   duration_text: string,
 *   duration_seconds: number,
 *   distance_text: string,
 *   distance_meters: number
 * }>}
 */
async function getDirections(originLat, originLng, destLat, destLng) {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;

  if (!apiKey) {
    throw new Error('GOOGLE_MAPS_API_KEY environment variable is not set');
  }

  const url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

  const body = JSON.stringify({
    origin: {
      location: {
        latLng: {
          latitude: originLat,
          longitude: originLng,
        },
      },
    },
    destination: {
      location: {
        latLng: {
          latitude: destLat,
          longitude: destLng,
        },
      },
    },
    travelMode: 'DRIVE',
  });

  logger.debug(
    { originLat, originLng, destLat, destLng },
    'Fetching directions from Google Routes API v2'
  );

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
    },
    body,
  });

  if (!response.ok) {
    const errText = await response.text().catch(() => '');
    // Do NOT include the API key in the error log or response
    logger.error(
      { status: response.status, body: errText.substring(0, 200) },
      'Google Routes API returned non-2xx status'
    );
    throw new Error(`Directions API request failed (HTTP ${response.status})`);
  }

  const data = await response.json();

  if (!data.routes || data.routes.length === 0) {
    logger.warn({ originLat, originLng, destLat, destLng }, 'No routes returned by Google Routes API');
    throw new Error('No route found between origin and destination');
  }

  const route = data.routes[0];

  const encodedPolyline = route.polyline?.encodedPolyline ?? '';

  // duration arrives as a string like "1250s"
  const durationStr = route.duration ?? '0s';
  const durationSeconds = parseInt(durationStr.replace('s', ''), 10) || 0;

  const distanceMeters = route.distanceMeters ?? 0;

  // Format duration as human-readable text
  const durationText = _formatDuration(durationSeconds);

  // Format distance as "X.X km"
  const distanceText = (distanceMeters / 1000).toFixed(1) + ' km';

  logger.debug(
    { durationText, distanceText },
    'Directions fetched successfully'
  );

  return {
    encoded_polyline  : encodedPolyline,
    duration_text     : durationText,
    duration_seconds  : durationSeconds,
    distance_text     : distanceText,
    distance_meters   : distanceMeters,
  };
}

/**
 * Convert seconds to "X hr Y min" or "Y min" string.
 * @param {number} seconds
 * @returns {string}
 */
function _formatDuration(seconds) {
  if (seconds <= 0) return '0 min';

  const totalMinutes = Math.round(seconds / 60);
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;

  if (hours > 0 && minutes > 0) {
    return `${hours} hr ${minutes} min`;
  }
  if (hours > 0) {
    return `${hours} hr`;
  }
  return `${minutes} min`;
}

module.exports = { getDirections };
