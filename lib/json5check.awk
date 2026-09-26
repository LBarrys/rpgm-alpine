{ buf = buf $0 "\n" }

function fail(msg) { print line ": " msg; exit 1 }

END {
	n = length(buf)
	i = 1
	line = 1
	depth = 0
	prev = "start"

	while (i <= n) {
		c = substr(buf, i, 1)

		if (c == "\n") { line++; i++; continue }
		if (c == " " || c == "\t" || c == "\r") { i++; continue }

		if (c == "/") {
			d = substr(buf, i + 1, 1)
			if (d == "/") { while (i <= n && substr(buf, i, 1) != "\n") i++; continue }
			if (d == "*") {
				i += 2
				while (i < n && substr(buf, i, 2) != "*/") { if (substr(buf, i, 1) == "\n") line++; i++ }
				if (i >= n) fail("unterminated /* comment")
				i += 2
				continue
			}
			fail("stray '/' (a comment starts with // or /*)")
		}

		if (c == "\"" || c == "'") {
			if (prev == "value" || prev == "close") fail("missing ',' before this")
			start = line
			i++
			while (i <= n) {
				d = substr(buf, i, 1)
				if (d == "\\") { if (substr(buf, i + 1, 1) == "\n") line++; i += 2; continue }
				if (d == c) break
				if (d == "\n") { print start ": unterminated string (no closing " c ")"; exit 1 }
				i++
			}
			if (i > n) fail("unterminated string")
			i++
			prev = "value"
			continue
		}

		if (c == "{" || c == "[") {
			if (prev == "value" || prev == "close") fail("missing ',' before this")
			depth++
			stack[depth] = c
			openline[depth] = line
			i++
			prev = "open"
			continue
		}

		if (c == "}" || c == "]") {
			want = (c == "}") ? "{" : "["
			if (depth == 0) fail("'" c "' without a matching '" want "'")
			if (stack[depth] != want) fail("'" c "' closes a '" stack[depth] "' opened on line " openline[depth])
			depth--
			i++
			prev = "close"
			continue
		}

		if (c == ",") {
			if (prev == "comma" || prev == "colon" || prev == "start") fail("stray ','")
			i++
			prev = "comma"
			continue
		}

		if (c == ":") {
			if (prev != "value") fail("stray ':'")
			i++
			prev = "colon"
			continue
		}

		if (prev == "value" || prev == "close") fail("missing ',' before this")
		while (i <= n && index(" \t\r\n{}[]:,/", substr(buf, i, 1)) == 0) i++
		prev = "value"
	}

	if (depth > 0) { print openline[depth] ": '" stack[depth] "' is never closed"; exit 1 }
}
