#!/usr/bin/env python3

import pathlib
import sys

def main():
	if len(sys.argv) != 2:
		print("usage: gen_page_tree.py destdir < input_def", file=sys.stderr)
		sys.exit(4)
	destdir = sys.argv[1]
	ast = sexp_ast(sys.stdin.read())
	if len(ast) != 1:
		print("invalid definition: have multiple roots", file=sys.stderr)
		sys.exit(5)

	pdest = pathlib.Path(destdir)
	if pdest.exists():
		print("error: %s exists" % (pdest,), file=sys.stderr)
		sys.exit(12)
	pdest.mkdir()

	gen = Gen(destdir)
	gen.make_res(ast[0])

class InputError(Exception):
	pass

def res_path(destdir, res_id, ext, is_static):
	if is_static:
		return pathlib.PosixPath(destdir, res_id + "." + ext)
	return pathlib.PosixPath(destdir, "dyn_" + res_id + "." + ext)

class Gen(object):
	def __init__(self, destdir):
		self._nres = 0
		self._dest = destdir
		self._static = []

	# make_res makes the resources specified according to the ast.
	# The return value is currently a (path, is_static, static_dep_list) tuple.
	def make_res(self, ast):
		if len(ast) < 2:
			raise InputError("operator or static/dynamic missing")
		op = ast[0]
		sta_dyn = ast[1]
		sub_exprs = ast[2:]
		if sta_dyn != "sta" and sta_dyn != "dyn":
			raise InputError("static/dynamic specifier must be sta or dyn")
		is_static = sta_dyn == "sta"
		if op == "page" or op == "iframe":
			if op == "page" and not is_static:
				raise InputError("page must be static")
			path = res_path(self._dest, self._new_res_id(), "html", is_static)
			g = HTMLGen(path)
			static_deps = []
			for expr in sub_exprs:
				sub_path, sub_static, sub_static_deps = self.make_res(expr)
				static_deps.extend(sub_static_deps)
				if expr[0] == "iframe":
					g.add_iframe(sub_path, sub_static)
				elif expr[0] == "css":
					g.add_css(sub_path, sub_static)
					if sub_static:
						static_deps.append(sub_path)
				elif expr[0] == "js":
					g.add_js(sub_path, sub_static)
					if sub_static:
						static_deps.append(sub_path)
				else:
					raise InputError("cannot use %s in page or iframe" % (expr[0],))
			g.close()
			write_static_deps_list(path, static_deps)
			return path, is_static, []
		elif op == "css":
			path = res_path(self._dest, self._new_res_id(), "css", is_static)
			g = CSSGen(path)
			static_deps = []
			for expr in sub_exprs:
				sub_path, sub_static, sub_static_deps = self.make_res(expr)
				static_deps.extend(sub_static_deps)
				if expr[0] == "css":
					g.add_css(sub_path, sub_static)
				else:
					raise InputError("cannot use %s in css" % (expr[0],))
				if sub_static:
					static_deps.append(sub_path)
			g.close()
			return path, is_static, static_deps
		elif op == "js":
			path = res_path(self._dest, self._new_res_id(), "js", is_static)
			g = JSGen(path)
			if sub_exprs:
				raise InputError("cannot use subresources in javascript")
			g.close()
			return path, is_static, []
		else:
			raise InputError("unknown operator " + str(ast[0]))

	def _new_res_id(self):
		r = self._nres
		self._nres += 1
		return str(r)

def get_url(path, is_static):
	if is_static:
		return str(path)
	return str(path) + "?@@@MAGIC_UUID@@@"

def write_static_deps_list(path, deps):
	with open(str(path) + ".deps", "w") as f:
		for d in deps:
			f.write(str(d))
			f.write("\n")

class HTMLGen(object):
	def __init__(self, dest):
		self._dest = dest
		self._lines = ["<!doctype html>", "<html>", "<body>"]

	def add_iframe(self, path, is_static):
		self._lines.append("<iframe src=\"" + get_url(path, is_static) + "\"></iframe>")

	def add_css(self, path, is_static):
		self._lines.append("<link rel=\"stylesheet\" type=\"text/css\" href=\"" + get_url(path, is_static) + "\">")

	def add_js(self, path, is_static):
		self._lines.append("<script src=\"" + get_url(path, is_static) + "\"></script>")

	def close(self):
		print(str(self._dest) + ": write")
		self._lines.extend(["</body>", "</html>", ""])
		self._dest.write_text("\n".join(self._lines))

class CSSGen(object):
	def __init__(self, dest):
		self._dest = dest
		self._lines = []

	def add_css(self, path, is_static):
		self._lines.append("@import url('" + get_url(path, is_static) + "');")

	def close(self):
		print(str(self._dest) + ": write")
		self._lines.append("")
		self._dest.write_text("\n".join(self._lines))

class JSGen(object):
	def __init__(self, dest):
		self._dest = dest
		self._lines = []

	def close(self):
		print(str(self._dest) + ": write")
		self._lines.append("")
		self._dest.write_text("\n".join(self._lines))

def sexp_ast(string):
	sexp = [[]]
	word = ""
	for c in string:
		if c == "(":
			sexp.append([])
		elif c == ")":
			if word:
				sexp[-1].append(word)
				word = ""
			temp = sexp.pop()
			sexp[-1].append(temp)
		elif c.isspace():
			if word:
				sexp[-1].append(word)
			word = ""
		else:
			word += c
	return sexp[0]

if __name__ == "__main__":
	main()
