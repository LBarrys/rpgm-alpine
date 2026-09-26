{ buf = buf $0 "\n" }

function take(v) {
	if (!want) return 0
	if (depth == 1 || (arrdepth && depth == arrdepth)) return 1
	return 0
}

function done() { if (!arrdepth) { want = 0; key = "" } }

END {
	n = length(buf)
	i = 1
	depth = 0
	arrdepth = 0
	key = ""
	want = 0

	while (i <= n) {
		c = substr(buf, i, 1)

		if (c == " " || c == "\t" || c == "\r" || c == "\n") { i++; continue }

		if (c == "/") {
			d = substr(buf, i + 1, 1)
			if (d == "/") { while (i <= n && substr(buf, i, 1) != "\n") i++; continue }
			if (d == "*") {
				i += 2
				while (i < n && substr(buf, i, 2) != "*/") i++
				i += 2
				continue
			}
			i++
			continue
		}

		if (c == "\"" || c == "'") {
			str = ""
			i++
			while (i <= n) {
				d = substr(buf, i, 1)
				if (d == "\\") { str = str substr(buf, i + 1, 1); i += 2; continue }
				if (d == c) break
				str = str d
				i++
			}
			i++
			if (take()) { print key "\t" str; done() }
			else if (!want && depth == 1) key = str
			continue
		}

		if (c == "[") {
			if (want && depth == 1) arrdepth = depth + 1
			depth++
			i++
			continue
		}

		if (c == "{") {
			if (want && depth == 1) print key "\t{}"
			depth++
			i++
			continue
		}

		if (c == "}" || c == "]") {
			depth--
			i++
			if (arrdepth && depth < arrdepth) { arrdepth = 0; want = 0; key = "" }
			else if (depth <= 1) { want = 0; key = "" }
			continue
		}

		if (c == ":") { want = 1; i++; continue }
		if (c == ",") { i++; continue }

		word = ""
		while (i <= n && index(" \t\r\n{}[]:,/'\"", substr(buf, i, 1)) == 0) {
			word = word substr(buf, i, 1)
			i++
		}
		if (word == "") { i++; continue }
		if (take()) { print key "\t" word; done() }
		else if (!want && depth == 1) key = word
	}
}
