import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/jaspr_content.dart';

import '../components/toc_highlighter.dart';

/// Docs layout wrapper that injects the TOC highlighter client component so
/// the scrolling logic always mounts.
class DocsLayoutWithTocHighlighter extends DocsLayout {
  const DocsLayoutWithTocHighlighter({super.sidebar, super.header, super.footer});

  @override
  Component buildBody(Page page, Component child) {
    final body = super.buildBody(page, child);

    // Render the layout plus a client-only hook that wires up toc-active toggling.
    return Component.fragment([
      body,
      const TocHighlighter(),
    ]);
  }
}
