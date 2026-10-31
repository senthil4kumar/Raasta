import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Safari only lets a page play incoming sound after a tap. Call this from tap
/// handlers so any silent (paused or blocked) remote audio starts playing.
void resumeAllAudio() {
  final elements = web.document.querySelectorAll('audio, video');
  for (var i = 0; i < elements.length; i++) {
    final el = elements.item(i);
    if (el != null && el.isA<web.HTMLMediaElement>()) {
      final media = el as web.HTMLMediaElement;
      if (media.paused || media.ended) {
        media.play().toDart.catchError((Object _) => null);
      }
    }
  }
}
