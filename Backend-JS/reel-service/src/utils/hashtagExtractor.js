function extractHashtags(content) {
  const hashtagRegex = /#[\w\u0590-\u05ff]+/g;
  const matches = content.match(hashtagRegex) || [];
  return [...new Set(matches.map((tag) => tag.slice(1).toLowerCase()))];
}

module.exports = extractHashtags;
