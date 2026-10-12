/// Source format of the extracted structured data.
enum SourceFormat {
  /// JSON-LD (`<script type="application/ld+json">`)
  jsonLd,

  /// HTML Microdata (`itemscope`, `itemprop`)
  microdata,

  /// RDFa Lite 1.1 (`vocab`, `typeof`, `property`)
  rdfaLite;

  @override
  String toString() {
    switch (this) {
      case SourceFormat.jsonLd:
        return 'JSON-LD';
      case SourceFormat.microdata:
        return 'Microdata';
      case SourceFormat.rdfaLite:
        return 'RDFa Lite';
    }
  }
}
