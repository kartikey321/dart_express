/// The entrypoint for the **server** environment.
///
/// The [main] method will only be executed on the server during pre-rendering.
/// To run code on the client, check the `main.client.dart` file.
library;

// Server-specific Jaspr import.
import 'package:jaspr/server.dart';

import 'package:jaspr_content/components/callout.dart';
// import 'package:jaspr_content/components/code_block.dart'; // Disabled
import 'package:jaspr_content/components/github_button.dart';
import 'package:jaspr_content/components/header.dart';
import 'package:jaspr_content/components/image.dart';
import 'package:jaspr_content/components/sidebar.dart';
import 'package:jaspr_content/components/theme_toggle.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import 'components/clicker.dart';

// This file is generated automatically by Jaspr, do not remove or edit.
import 'main.server.options.dart';

void main() {
  // Initializes the server environment with the generated default options.
  Jaspr.initializeApp(
    options: defaultServerOptions,
  );

  // Starts the app.
  //
  // [ContentApp] spins up the content rendering pipeline from jaspr_content to render
  // your markdown files in the content/ directory to a beautiful documentation site.
  runApp(
    ContentApp(
      // Enables mustache templating inside the markdown files.
      templateEngine: MustacheTemplateEngine(),
      parsers: [
        MarkdownParser(),
      ],
      extensions: [
        // Adds heading anchors to each heading.
        HeadingAnchorsExtension(),
        // Generates a table of contents for each page.
        TableOfContentsExtension(),
      ],
      components: [
        // The <Info> block and other callouts.
        Callout(),
        // Adds syntax highlighting to code blocks.
        // CodeBlock(), // Temporarily disabled due to highlighter errors
        // Adds a custom Jaspr component to be used as <Clicker/> in markdown.
        CustomComponent(
          pattern: 'Clicker',
          builder: (_, _, _) => Clicker(),
        ),
        // Adds zooming and caption support to images.
        Image(zoom: true),
      ],
      layouts: [
        // Out-of-the-box layout for documentation sites.
        DocsLayout(
          header: Header(
            title: 'dart_express',
            logo: '',
            items: [
              // Enables switching between light and dark mode.
              ThemeToggle(),
              // Shows github stats.
              GitHubButton(repo: 'kartikey321/dart_express'),
            ],
          ),
          sidebar: Sidebar(
            groups: [
              SidebarGroup(
                title: 'Getting Started',
                links: [
                  SidebarLink(text: "Overview", href: '/'),
                  SidebarLink(text: "Installation", href: '/getting-started/installation'),
                  SidebarLink(text: "Quick Start", href: '/getting-started/quick-start'),
                ],
              ),
              SidebarGroup(
                title: 'Core Concepts',
                links: [
                  SidebarLink(text: "Routing", href: '/core-concepts/routing'),
                  SidebarLink(text: "Middleware", href: '/core-concepts/middleware'),
                  SidebarLink(text: "Sessions", href: '/core-concepts/sessions'),
                  SidebarLink(text: "Error Handling", href: '/core-concepts/error-handling'),
                ],
              ),
              SidebarGroup(
                title: 'Security',
                links: [
                  SidebarLink(text: "CORS", href: '/security/cors'),
                ],
              ),
              SidebarGroup(
                title: 'Deployment',
                links: [
                  SidebarLink(text: "Docker", href: '/deployment/docker'),
                ],
              ),
              SidebarGroup(
                title: 'Examples',
                links: [
                  SidebarLink(text: "TODO API", href: '/examples/todo-api'),
                ],
              ),
              SidebarGroup(
                title: 'Learn More',
                links: [
                  SidebarLink(text: "About", href: '/about'),
                ],
              ),
            ],
          ),
        ),
      ],
      theme: ContentTheme(
        // Customizes the default theme colors.
        primary: ThemeColor(ThemeColors.blue.$500, dark: ThemeColors.blue.$300),
        background: ThemeColor(ThemeColors.slate.$50, dark: ThemeColors.zinc.$950),
        colors: [
          ContentColors.quoteBorders.apply(ThemeColors.blue.$400),
        ],
      ),
    ),
  );
}
