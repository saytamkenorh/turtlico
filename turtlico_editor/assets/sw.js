var cacheName = 'turtlico-pwa';
var filesToCache = [
  './',
  './index.html',
  './index.js',
  './worker.js',
  './turtlico_editor.js',
  './favicon.ico',
  './turtlico_editor_bg.wasm',
];

/* Start the service worker and cache all of the app's content */
self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(cacheName).then(function (cache) {
      return cache.addAll(filesToCache);
    })
  );
});

/* Serve cached content when offline */
self.addEventListener('fetch', function (e) {
  e.respondWith(
    caches.match(e.request).then(function (response) {
      return response || fetch(e.request);
    })
  );
});
