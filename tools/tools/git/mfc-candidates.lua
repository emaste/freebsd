#!/usr/libexec/flua

-- SPDX-License-Identifier: BSD-2-Clause
-- Copyright 2024 The FreeBSD Foundation

-- MFC candidate search utility.  Identify hashes that exist only in the
-- "MFC from" branch and do not have a corresponding "cherry picked from"
-- commit in the "MFC to" branch.

-- Execute a command and return its output.  A final newline is stripped,
-- similar to sh.
local function exec_command(command)
	local handle = assert(io.popen(command))
	local output = handle:read("a")
	handle:close()
	if output:sub(-1) == "\n" then
		return output:sub(1, -2)
	end
	return output
end

-- Return a table of cherry-pick (MFC) candidates.
local function read_from(from_branch, to_branch, author, dirspec)
	local command = "git rev-list --first-parent --reverse "
	command = command .. to_branch .. ".." .. from_branch
	if #author > 0 then
		command = command .. " --committer \\<" .. author .. "@"
	end
	if dirspec then
		command = command .. " " .. dirspec
	end
	if verbose > 1 then
		print("Obtaining MFC-from commits using command:")
		print(command)
	end
	local handle = assert(io.popen(command))
	local content = {}
	for line in handle:lines() do
		table.insert(content, line)
	end
	handle:close()
	return content
end

-- Expand hash if it is short.  Git SHA-1 hashes are 40 characters.
local function expand_hash(hash)
	if #hash < 40 then
		if verbose > 1 then
			print("Expanding short hash " .. hash)
		end
		local expanded = exec_command(
		    "git rev-parse " .. hash .. " 2>/dev/null")
		if #expanded == 40 then
			hash = expanded
		elseif verbose > 0 then
			print("Unable to expand hash \"" .. hash .. "\"")
			hash = nil
		end
		--print("hash = |" .. hash .. "|")
--		if #expanded < 40 and verbose > 0 then
--			print("Unable to expand '" .. hash .. "'")
--		end
	end
	return hash
end

-- Return a table of original hashes of changes that have already been
-- cherry-picked (MFC'd).
local function read_to(from_branch, to_branch, grep, expression, dirspec)
	local command = "git log --first-parent " .. from_branch .. ".." .. to_branch
	command = command .. " --grep '" .. grep .. "'"
	if dirspec then
		command = command .. " " .. dirspec
	end
	if verbose > 1 then
		print("Obtaining MFC-to commits using command:")
		print(command)
	end
	local handle = assert(io.popen(command))
	local content = {}
	for line in handle:lines() do
		local hash = line:match(expression)
		if hash then
			hash = expand_hash(hash)
			if hash then
				table.insert(content, hash)
			end
		end
	end
	handle:close()
	return content
end

-- Read a commit exclude file and return its content as a table.  Comments
-- starting with # and text after a hash is ignored.
local function read_exclude(filename)
	local file = assert(io.open(filename, "r"))
	local content = {}
	for line in file:lines() do
		local hash = line:match("^%x+")
		if hash then
			hash = expand_hash(hash)
			table.insert(content, hash)
		end
	end
	file:close()
	return content
end

--- Remove hashes from 'set1' list that are present in 'set2' list
local function set_difference(set1, set2)
	local set2_values = {}
	for _, value in ipairs(set2) do
		set2_values[value] = true
	end

	local result = {}
	for _, value in ipairs(set1) do
		if not set2_values[value] then
			table.insert(result, value)
		end
	end
	return result
end

local function set_intersection(set1, set2)
	local result = {}
	for _, element in ipairs(set1) do
		for _, e2 in ipairs(set2) do
			if e2 == element then
				result[#result+1] = element
			end
		end
	end
	return result
end

-- Global state
verbose = 0

local function params(from_branch, to_branch, author)
	print("from:             " .. from_branch)
	print("to:               " .. to_branch)
	if #author > 0 then
		print("author/committer: " .. author)
	else
		print("author/committer: <all>")
	end
end

local function usage(from_branch, to_branch, author)
	local script_name = arg[0]:match("([^/]+)$")
	print(script_name .. " [-ah] [-f from_branch] [-t to_branch] [-u user] [-X exclude_file] [path ...]")
	print()
	params(from_branch, to_branch, author)
end

-- Main function
local function main()
	local from_branch = "freebsd/main"
	local to_branch = ""
	local author = os.getenv("USER") or ""
	local dirspec = nil

	local url = exec_command("git remote get-url freebsd")
	local freebsd_repo = string.match(url, "[^/]+$")
	freebsd_repo = string.gsub(freebsd_repo, ".git$", "")
	if freebsd_repo == "ports" or freebsd_repo == "freebsd-ports" then
		local year = os.date("%Y")
		local month = os.date("%m")
		local qtr = math.ceil(month / 3)
		to_branch = "freebsd/" .. year .. "Q" .. qtr
	elseif freebsd_repo == "src" or freebsd_repo == "freebsd-src" then
		to_branch = "freebsd/stable/14"
		-- If pwd is a stable or release branch tree, default to it.
		local cur_branch = exec_command("git symbolic-ref --short HEAD")
		if string.match(cur_branch, "^stable/") then
			to_branch = cur_branch
		elseif string.match(cur_branch, "^releng/") then
			to_branch = cur_branch
			local major = string.match(cur_branch, "%d+")
			from_branch = "freebsd/stable/" .. major
		end
	else
		print("pwd is not under a ports or src repository.")
		return
	end

	local do_help = false
	local exclude_file = nil
	local fixes = false
	local i = 1
	while i <= #arg and arg[i] do
		local opt = arg[i]
		if opt == "-F" then
			fixes = true
		elseif opt == "-a" then
			author = ""
		elseif opt == "-f" then
			from_branch = arg[i + 1]
			i = i + 1
		elseif opt == "-h" then
			do_help = true
			i = i + 1
		elseif opt == "-t" then
			to_branch = arg[i + 1]
			i = i + 1
		elseif opt == "-u" then
			author = arg[i + 1]
			i = i + 1
		elseif opt == "-v" then
			verbose = verbose + 1
		elseif opt == "-X" then
			exclude_file = arg[i + 1]
			i = i + 1
		else
			break
		end
		i = i + 1
	end

	if do_help then
		usage(from_branch, to_branch, author)
		return
	end

	while arg[i] do
		if dirspec then
			dirspec = dirspec .. " " .. arg[i]
		else
			dirspec = arg[i]
		end
		i = i + 1
	end

	if verbose > 0 then
		params(from_branch, to_branch, author)
	end

	if fixes then
		print("Fixes mode")
		local already_hashes = read_from(to_branch, from_branch, author, dirspec)
		local fixes_expr = "Fixes:%s*([0-9a-f]+)"
		local fixes_hashes = read_to(to_branch, from_branch, "Fixes:", fixes_expr, dirspec)
--		print("Fixes hashes:")
--		for _, hash in ipairs(fixes_hashes) do
--			print(hash)
--		end
		local result_hashes = set_intersection(already_hashes, fixes_hashes)
		for _, hash in ipairs(result_hashes) do
			print(exec_command("git show --pretty='%h %s' --no-patch " .. hash))
		end
		return
	end

	local from_hashes = read_from(from_branch, to_branch, author, dirspec)
	local cherry_expr = "%(cherry picked from commit ([0-9a-f]+)%)"
	local to_hashes = read_to(from_branch, to_branch, "cherry picked from", cherry_expr, dirspec)

	local result_hashes = set_difference(from_hashes, to_hashes)

	if exclude_file then
		exclude_hashes = read_exclude(exclude_file)
		result_hashes = set_difference(result_hashes, exclude_hashes)
	end

	-- Print the result
	for _, hash in ipairs(result_hashes) do
		print(exec_command("git show --pretty='%h %s' --no-patch " .. hash))
	end
end

main()
