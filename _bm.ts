import * as mfm from './built/index';

const srcs: Record<string, string> = {
	'text10': 'あいうえおかきくけこ\n',
	'text30': 'あいうえおかきくけこ\sさしすせそたちつてと\nなにぬねのはひふへほ\n',
	'text50': 'あいうえおかきくけこ\sさしすせそたちつてと\nなにぬねのはひふへほ\nまみむめもやいゆえよ\nわいうえおいろはにほ\n',
	'mention': '@user@example.com あいうえおかきくけこさしすせそたちつてと\nあいうえおかきくけこさしすせそたちつてと\n',
	'hashtag': 'いうえおかきくけこさしすせそたちつてと\nあいうえおかきくけこさしすせそたちつてと\n#hashtag ',
	'url': 'あいうえおかきくけこさしすせそたちつてと\nあいうえおかきくけこさしすせそたちつてと\nhttps://example.com/foo/bar.baz',
};

const tests:  Record<string, Function> = {
	'js_full': (src: string) => {
		mfm.parse(src);
	},
	'js_plain': (src: string) => {
		mfm.parsePlain(src);
	},

	'js_basic': (src: string) => {
		mfm.parseBasic(src);
	},
};

for (const key of Object.keys(tests)) {
	for (const src of Object.keys(srcs)) {
		console.time(`${key} / ${src}: `);
		for (let i = 0; i < 100; i++) {
			tests[key](srcs[src]);
		}
		console.timeEnd(`${key} / ${src}: `);
	}
}
