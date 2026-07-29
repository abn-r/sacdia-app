/// Returns true when [url] points to an SVG resource.
///
/// Uses the URL path (ignoring query/fragment) so signed R2 URLs like
/// `https://…/badge.svg?X-Amz-Signature=…` still detect as SVG.
bool isSvgNetworkUrl(String url) {
  final uri = Uri.tryParse(url);
  final path = (uri?.path.isNotEmpty == true ? uri!.path : url).toLowerCase();
  return path.endsWith('.svg');
}
