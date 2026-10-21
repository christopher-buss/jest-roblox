-- ROBLOX upstream: no upstream
local CurrentModule = script.Parent
local SrcModule = CurrentModule.Parent
local Packages = SrcModule.Parent.Parent

local JestGlobals = require(Packages.Dev.JestGlobals)
local expect = JestGlobals.expect
local describe = JestGlobals.describe
local it = JestGlobals.it

local RegExp = require(Packages.RegExp)
local eventHandler = require(CurrentModule.Parent.eventHandler).default

local typesModule = require(Packages.JestTypes)
type Circus_Event = typesModule.Circus_Event
type Circus_State = typesModule.Circus_State

describe("eventHandler", function()
	it("should not fail when called with testNamePattern", function()
		local event = ({ name = "setup", testNamePattern = "apattern" } :: any) :: Circus_Event
		local state = {} :: Circus_State
		expect(function()
			eventHandler(nil, event, state)
		end).never.toThrow()
	end)

	it("should add testNamePattern to the state", function()
		local pattern = "apattern"
		local event = ({ name = "setup", testNamePattern = pattern } :: any) :: Circus_Event
		local state = {} :: Circus_State
		eventHandler(nil, event, state)

		expect(state.testNamePattern).toBeDefined()
		expect(state.testNamePattern).toBeInstanceOf(RegExp)
		expect(state.testNamePattern).toEqual(RegExp(pattern, "i"))
	end)

	describe("testNamePattern as a group of escaped literals", function()
		local names = {
			"reads a.b (c) [d] {e} ^f$ g|h * + ? \\ end",
			"Mixed CASE",
			"short",
		}

		local function escape(name: string): string
			return (string.gsub(name, "[%$%(%)%*%+%.%?%[%]%^{|}\\]", "\\%0"))
		end

		local function setup(pattern: string): Circus_State
			local event = ({ name = "setup", testNamePattern = pattern } :: any) :: Circus_Event
			local state = {} :: Circus_State
			eventHandler(nil, event, state)
			return state
		end

		it("should select test names containing any literal", function()
			local escaped = {}
			for _, name in names do
				table.insert(escaped, escape(name))
			end
			local state = setup("(" .. table.concat(escaped, "|") .. ")")

			expect(state.testNamePattern).never.toBeInstanceOf(RegExp)
			for _, case in
				{
					{ "suite reads a.b (c) [d] {e} ^f$ g|h * + ? \\ end", true },
					{ "suite reads aXb (c) [d] {e} ^f$ g|h * + ? \\ end", false },
					{ "suite keeps Mixed CASE too", true },
					{ "suite keeps mixed case", false },
					{ "suite short and longer", true },
					{ "suite shor", false },
					{ "suite unchosen", false },
					{ "", false },
				}
			do
				expect({ case[1], (state.testNamePattern :: any):test(case[1]) }).toEqual(case)
			end
		end)

		it("should match every name when an alternative is empty", function()
			local state = setup("(short|)")

			expect((state.testNamePattern :: any):test("suite unchosen")).toBe(true)
		end)

		it.each({
			"apattern",
			"(a.b)",
			"(a|b)c",
			"a(b|c)",
			"(a)|(b)",
			"(a\\d)",
		})("should use RegExp for %s", function(pattern: string)
			local state = setup(pattern)

			expect(state.testNamePattern).toBeInstanceOf(RegExp)
			expect(state.testNamePattern).toEqual(RegExp(pattern, "i"))
		end)
	end)
end)
