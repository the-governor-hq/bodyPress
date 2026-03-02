import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/body_blog_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────────────────────────────────────

const double kSocialCardWidth = 380;
const double kSocialCardHeight = 420; // portrait-ish — shows nicely in feed
const double kSocialCardPixelRatio = 3.0; // → 1140 × 1260 px PNG

const _bg = Color(0xFF080808);
const _white = Color(0xFFFFFFFF);
const _cream = Color(0xFFF2ECD6); // warm editorial tint
const _dim = Color(0x66FFFFFF); // 40 % white
const _rule = Color(0xFF282828); // separator
const _tagBg = Color(0xFF161620);
const _tagBorder = Color(0xFF2E2E40);
const _tagText = Color(0xFF8888BB);
const _urlColor = Color(0xFF5C5C78);
const _accent = Color(0xFF6C63FF); // indigo dot — the only splash of colour

// ─────────────────────────────────────────────────────────────────────────────
//  SocialCard widget
// ─────────────────────────────────────────────────────────────────────────────

/// An off-screen shareable card rendered at [kSocialCardWidth] × [kSocialCardHeight].
///
/// Design: NYT Op-Ed × health journal.
///   • Pure-black field — maximum contrast.
///   • Playfair Display headline — the editorial centrepiece.
///   • Thin structural rules for rhythm.
///   • "BODYPRESS" monogram + indigo dot top-left.
///   • Italic italic summary excerpt in warm cream.
///   • Tag pills at the bottom.
///   • "bodypress ↗" watermark — subtle growth hook.
class SocialCard extends StatelessWidget {
  const SocialCard({super.key, required this.entry});

  final BodyBlogEntry entry;

  @override
  Widget build(BuildContext context) {
    final headline = _clamp(entry.headline, 100);
    final excerpt = _excerpt(entry.summary);
    final dateStr = DateFormat('MMMM d, yyyy').format(entry.date).toUpperCase();
    final cardTags = entry.tags.take(3).toList();

    return SizedBox(
      width: kSocialCardWidth,
      height: kSocialCardHeight,
      child: Material(
        color: _bg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Mood pill — top-right only, keeps the top clean ──────────
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${entry.moodEmoji}  ${entry.mood.toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: _dim,
                  ),
                ),
              ),

              // ── First rule ───────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: _HRule(),
              ),

              // ── Headline — the star ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      headline,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: _headlineFontSize(headline),
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                        color: _white,
                      ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (excerpt.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      // Left accent bar + excerpt
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 2,
                              color: _accent.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '"$excerpt"',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w300,
                                  fontStyle: FontStyle.italic,
                                  height: 1.55,
                                  color: _cream.withValues(alpha: 0.62),
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Bottom section ───────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cardTags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: cardTags
                          .map((t) => _SocialTag(label: t))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── BodyPress masthead — sits above the data bar ─────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BodyPress',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: _white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· body journal',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.2,
                          color: _dim,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  const _HRule(),
                  const SizedBox(height: 10),

                  // Date ← → URL
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1,
                          color: _dim,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Read more at  ',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w300,
                              color: _urlColor,
                            ),
                          ),
                          Text(
                            'bodypress',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: const Color(0xFF8888CC),
                            ),
                          ),
                          Text(
                            '  ↗',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: _accent.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  static double _headlineFontSize(String text) {
    if (text.length < 35) return 30;
    if (text.length < 55) return 26;
    if (text.length < 75) return 23;
    return 20;
  }

  static String _clamp(String text, int max) =>
      text.length > max ? '${text.substring(0, max - 1)}…' : text;

  static String _excerpt(String summary) {
    if (summary.isEmpty) return '';
    // First natural sentence that's long enough to be interesting
    final match = RegExp(r'[^.!?]{25,}[.!?]').firstMatch(summary);
    if (match != null) {
      final s = match.group(0)!.trim();
      return s.length > 120 ? '${s.substring(0, 117)}…' : s;
    }
    return summary.length > 110 ? '${summary.substring(0, 107)}…' : summary;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared primitives
// ─────────────────────────────────────────────────────────────────────────────

class _HRule extends StatelessWidget {
  const _HRule();

  @override
  Widget build(BuildContext context) => Container(height: 0.5, color: _rule);
}

class _SocialTag extends StatelessWidget {
  const _SocialTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _tagBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tagBorder, width: 0.5),
      ),
      child: Text(
        '#$label',
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: _tagText,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SocialCardCapture — off-screen render → PNG → share
// ─────────────────────────────────────────────────────────────────────────────

/// Inserts an off-screen [SocialCard] into the overlay, captures it as a
/// high-res PNG ([kSocialCardPixelRatio]× = ~1140 × 1260 px), then opens
/// the native share sheet.
///
/// Uses the Overlay approach so the card is never visible to the user — it
/// lives at `left: -(width + 200)` for a single frame, gets photographed,
/// and is removed before the user blinks.
class SocialCardCapture {
  SocialCardCapture._();

  static Future<bool> captureAndShare({
    required BuildContext context,
    required BodyBlogEntry entry,
  }) async {
    final captureKey = GlobalKey();
    OverlayEntry? overlay;

    try {
      overlay = OverlayEntry(
        builder: (_) => Positioned(
          // Hard off-screen — never visible
          left: -(kSocialCardWidth + 200),
          top: 0,
          width: kSocialCardWidth,
          height: kSocialCardHeight,
          child: RepaintBoundary(
            key: captureKey,
            child: SocialCard(entry: entry),
          ),
        ),
      );

      // ignore: use_build_context_synchronously
      Overlay.of(context).insert(overlay);

      // Give the rasteriser a frame to lay the widget out
      await Future.delayed(const Duration(milliseconds: 220));

      final boundary =
          captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return false;

      final image = await boundary.toImage(pixelRatio: kSocialCardPixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;

      final pngBytes = byteData.buffer.asUint8List();

      await _shareBytes(pngBytes, entry);
      return true;
    } catch (e) {
      debugPrint('[SocialCardCapture] $e');
      return false;
    } finally {
      overlay?.remove();
    }
  }

  static Future<void> _shareBytes(Uint8List bytes, BodyBlogEntry entry) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bodypress_share.png');
    await file.writeAsBytes(bytes);

    final dateStr = DateFormat('MMMM d, y').format(entry.date);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: entry.headline,
      text: '${entry.headline}\n\n$dateStr — bodypress',
    );
  }
}
