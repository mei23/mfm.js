{
	function createNode(type, props, children) {
		const node = { type };
		if (props != null) {
			node.props = props;
		}
		if (children != null) {
			node.children = children;
		}
		return node;
	}

	function mergeText(nodes) {
		const dest = [];
		const storedChars = [];
		function generateText() {
			if (storedChars.length > 0) {
				const textNode = createNode('text', { text: storedChars.join('') });
				dest.push(textNode);
				storedChars.length = 0;
			}
		}
		for (const node of nodes) {
			if (typeof node == 'string') {
				storedChars.push(node);
			}
			else {
				generateText();
				dest.push(node);
			}
		}
		generateText();
		return dest;
	}

	let consumeCount = 0;

	function setConsumeCount(count) {
		consumeCount = count;
	}

	function consumeDynamically() {
		const matched = (consumeCount > 0);
		if (matched) {
			consumeCount--;
		}
		return matched;
	}

	function applyParser(input, startRule) {
		let parseFunc = peg$parse;
		return parseFunc(input, startRule ? { startRule } : { });
	}

	// emoji

	const emojiRegex = require('twemoji-parser/dist/lib/regex').default;
	const anchoredEmojiRegex = RegExp(`^(?:${emojiRegex.source})`);

	/**
	 * check if the input matches the emoji regexp.
	 * if they match, set the byte length of the emoji.
	*/
	function matchUnicodeEmoji() {
		const offset = location().start.offset;
		const src = input.substr(offset);

		const result = anchoredEmojiRegex.exec(src);
		if (result != null) {
			setConsumeCount(result[0].length); // length(utf-16 byte length) of emoji sequence.
			return true;
		}

		return false;
	}
}

//
// parsers
//

fullParser
	= nodes:(&. n:full { return n; })* { return mergeText(nodes); }

plainParser
	= nodes:(&. n:plain { return n; })* { return mergeText(nodes); }

inlineParser
	= nodes:(&. n:inline { return n; })* { return mergeText(nodes); }

basicParser
	= nodes:(&. n:inlineBasic { return n; })* { return mergeText(nodes); }

//
// syntax list
//

full
	= quote // block
	/ codeBlock // block
	/ mathBlock // block
	/ center // block
	/ emojiCode
	/ unicodeEmoji
	/ big
	/ bold
	/ small
	/ italic
	/ strike
	/ inlineCode
	/ mathInline
	/ mention
	/ hashtag
	/ url
	/ fnVer2
	/ link
	/ fnVer1
	/ search // block
	/ inlineText

inline
	= emojiCode
	/ unicodeEmoji
	/ big
	/ bold
	/ small
	/ italic
	/ strike
	/ inlineCode
	/ mathInline
	/ mention
	/ hashtag
	/ url
	/ fnVer2
	/ link
	/ fnVer1
	/ inlineText

inlineWithoutFn
	= emojiCode
	/ unicodeEmoji
	/ big
	/ bold
	/ small
	/ italic
	/ strike
	/ inlineCode
	/ mathInline
	/ mention
	/ hashtag
	/ url
	/ link
	/ inlineText

inlineBasic
	= emojiCode
	/ unicodeEmoji
	/ inlineCode
	/ mention
	/ hashtag
	/ url
	/ link
	/ inlineText

plain
	= emojiCode
	/ unicodeEmoji
	/ plainText

//
// block rules
//

// block: quote

quote
	= &(BEGIN ">") q:quoteInner { return q; }

quoteInner
	= head:quoteMultiLine tails:quoteMultiLine+
{
	const children = applyParser([head, ...tails].join('\n'), 'fullParser');
	return createNode('quote', null, children);
}
	/ line:quoteLine
{
	const children = applyParser(line, 'fullParser');
	return createNode('quote', null, children);
}

quoteMultiLine
	= quoteLine / quoteEmptyLine

quoteLine
	= BEGIN ">" _? text:$(CHAR+) END { return text; }

quoteEmptyLine
	= BEGIN ">" _? END { return ''; }

// block: search

search
	= BEGIN q:searchQuery sp:_ key:searchKey END
{
	return createNode('search', {
		query: q,
		content: `${ q }${ sp }${ key }`
	});
}

searchQuery
	= (!(_ searchKey END) CHAR)+ { return text(); }

searchKey
	= "[" ("検索" / "Search"i) "]" { return text(); }
	/ "検索"
	/ "Search"i

// block: codeBlock

codeBlock
	= BEGIN "```" lang:$(CHAR*) LF code:codeBlockContent LF "```" END
{
	lang = lang.trim();
	return createNode('blockCode', {
		code: code,
		lang: lang.length > 0 ? lang : null,
	});
}

codeBlockContent
	= (!(LF "```" END) .)+
{ return text(); }

// block: mathBlock

mathBlock
	= BEGIN "\\[" LF? formula:mathBlockLines LF? "\\]" END
{
	return createNode('mathBlock', {
		formula: formula.trim()
	});
}

mathBlockLines
	= mathBlockLine (LF mathBlockLine)*
{ return text(); }

mathBlockLine
	= (!"\\]" CHAR)+

// block: center

center
	= BEGIN "<center>" LF? content:(!(LF? "</center>" END) i:inline { return i; })+ LF? "</center>" END
{
	return createNode('center', null, mergeText(content));
}

//
// inline rules
//

// inline: emoji code

emojiCode
	= ":" name:emojiCodeName ":"
{
	return createNode('emojiCode', { name: name });
}

emojiCodeName
	= [a-z0-9_+-]i+ { return text(); }

// inline: unicode emoji

// NOTE: if the text matches one of the emojis, it will count the length of the emoji sequence and consume it.
unicodeEmoji
	= &{ return matchUnicodeEmoji(); } (&{ return consumeDynamically(); } .)+
{
	return createNode('unicodeEmoji', { emoji: text() });
}

// inline: big

big
	= "***" content:(!"***" i:inline { return i; })+ "***"
{
	return createNode('fn', {
		name: 'tada',
		args: { }
	}, mergeText(content));
}

// inline: bold

bold
	= "**" content:(!"**" i:inline { return i; })+ "**"
{
	return createNode('bold', null, mergeText(content));
}
	/ "__" content:$(!"__" c:([a-z0-9]i / _) { return c; })+ "__"
{
	const parsedContent = applyParser(content, 'inlineParser');
	return createNode('bold', null, parsedContent);
}

// inline: small

small
	= "<small>" content:(!"</small>" i:inline { return i; })+ "</small>"
{
	return createNode('small', null, mergeText(content));
}

// inline: italic

italic
	= italicTag
	/ italicAlt

italicTag
	= "<i>" content:(!"</i>" i:inline { return i; })+ "</i>"
{
	return createNode('italic', null, mergeText(content));
}

italicAlt
	= "*" content:$(!"*" ([a-z0-9]i / _))+ "*" &(EOF / LF / _)
{
	const parsedContent = applyParser(content, 'inlineParser');
	return createNode('italic', null, parsedContent);
}
	/ "_" content:$(!"_" ([a-z0-9]i / _))+ "_" &(EOF / LF / _)
{
	const parsedContent = applyParser(content, 'inlineParser');
	return createNode('italic', null, parsedContent);
}

// inline: strike

strike
	= "~~" content:(!("~" / LF) i:inline { return i; })+ "~~"
{
	return createNode('strike', null, mergeText(content));
}

// inline: inlineCode

inlineCode
	= "`" content:$(!"`" c:CHAR { return c; })+ "`"
{
	return createNode('inlineCode', {
		code: content
	});
}

// inline: mathInline

mathInline
	= "\\(" content:$(!"\\)" c:CHAR { return c; })+ "\\)"
{
	return createNode('mathInline', {
		formula: content
	});
}

// inline: mention

mention
	= "@" name:mentionName host:("@" host:mentionHost { return host; })?
{
	return createNode('mention', {
		username: name,
		host: host,
		acct: text()
	});
}

mentionName
	= !"-" mentionNamePart+ // first char is not "-".
{
	return text();
}

mentionNamePart
	= "-" &mentionNamePart // last char is not "-".
	/ [a-z0-9_]i

mentionHost
	= ![.-] mentionHostPart+ // first char is neither "." nor "-".
{
	return text();
}

mentionHostPart
	= [.-] &mentionHostPart // last char is neither "." nor "-".
	/ [a-z0-9_]i

// inline: hashtag

hashtag
	= "#" !("\uFE0F"? "\u20E3") content:hashtagContent
{
	return createNode('hashtag', { hashtag: content });
}

hashtagContent
	= hashtagChar+ { return text(); }

hashtagChar
	= ![ 　\t.,!?'"#:\/【】] CHAR

// hashtagContent
// 	= (hashtagBracketPair / hashtagChar)+ { return text(); }

// hashtagBracketPair
// 	= "(" hashtagContent* ")"
// 	/ "[" hashtagContent* "]"
// 	/ "「" hashtagContent* "」"

// hashtagChar
// 	= ![ 　\t.,!?'"#:\/\[\]【】()「」] CHAR

// inline: URL

url
	= "<" url:urlFormat ">"
{
	return createNode('url', { url: url });
}
	/ url:urlFormat
{
	return createNode('url', { url: url });
}

urlFormat
	= "http" "s"? "://" urlContent
{
	return text();
}

urlContent
	= urlContentPart+

urlContentPart
	= [.,] &urlContentPart // last char is neither "." nor ",".
	/ [a-z0-9_/:%#@$&?!~=+-]i

// urlContentPart
// 	= urlBracketPair
// 	/ [.,] &urlContentPart // last char is neither "." nor ",".
// 	/ [a-z0-9_/:%#@$&?!~=+-]i

// urlBracketPair
// 	= "(" urlContentPart* ")"
// 	/ "[" urlContentPart* "]"

// inline: link

link
	= silent:"?"? "[" label:linkLabel "](" url:linkUrl ")"
{
	return createNode('link', {
		silent: (silent != null),
		url: url
	}, mergeText(label));
}

linkLabel
	= parts:linkLabelPart+
{
	return parts;
	//return parts.flat(Infinity);
}

// linkLabelPart
// 	= url { return text(); /* text node */ }
// 	/ link { return text(); /* text node */ }
// 	/ !"]" n:inline { return n; }

linkLabelPart
	// = "[" linkLabelPart* "]"
	= !"]" p:plain { return p; }

linkUrl
	= url { return text(); }

// inline: fn

fnVer1
	= "[" name:$([a-z0-9_]i)+ args:fnArgs? _ content:fnContentPart+ "]"
{
	args = args || {};
	return createNode('fn', {
		name: name,
		args: args
	}, mergeText(content));
}

fnVer2
	= "$[" name:$([a-z0-9_]i)+ args:fnArgs? _ content:fnContentPart+ "]"
{
	args = args || {};
	return createNode('fn', {
		name: name,
		args: args
	}, mergeText(content));
}

fnArgs
	= "." head:fnArg tails:("," arg:fnArg { return arg; })*
{
	const args = { };
	for (const pair of [head, ...tails]) {
		args[pair.k] = pair.v;
	}
	return args;
}

fnArg
	= k:$([a-z0-9_]i)+ "=" v:$([a-z0-9_.]i)+
{
	return { k, v };
}
	/ k:$([a-z0-9_]i)+
{
	return { k: k, v: true };
}

fnContentPart
	= !("]") i:inlineWithoutFn { return i; }

// inline: text

inlineText
	= !(LF / _) . &(hashtag / mention / italicAlt) . { return text(); } // hashtag, mention, italic ignore
	/ . /* text node */

// inline: text (for plainParser)

plainText
	= . /* text node */

//
// General
//

BEGIN "beginning of line"
	= LF / &{ return location().start.column == 1; }

END "end of line"
	= LF / EOF

EOF
	= !.

CHAR
	= !LF . { return text(); }

LF
	= "\r\n" / [\r\n]

_ "whitespace"
	= [ 　\t\u00a0]
