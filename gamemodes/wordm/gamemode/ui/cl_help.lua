surface.CreateFont( "HelpTitle", { font = "Roboto", size = 72, weight = 1000, antialias = true, } )
surface.CreateFont( "HelpSubTitle", { font = "Roboto", size = 30, weight = 500, antialias = true, } )
surface.CreateFont( "HelpDetails", { font = "Tahoma", size = 20, weight = 800, antialias = true, } )
surface.CreateFont( "HelpRow", { font = "Tahoma", size = 18, weight = 1000, antialias = true, } )


local HelpText = [[
	<font=HelpTitle>WorDM</font>
	<font=HelpSubTitle><colour=200,200,200,255>A gamemode by Kazditi</colour></font>
	<font=HelpSubTitle><colour=120,120,120,255>"Sticks and stones may break your bones, but words will ALWAYS hurt you."</colour></font>
	<font=HelpDetails>
	Typing many words, good for becoming win at this game.
	Big words 'chronocinematography' or 'hyperemphasizing' are hurt more, and more words makes better!

	Word scoring does calculate like so:
	<colour=255,100,100,255> - Bad spelling is give you zero points.</colour>
	<colour=255,100,100,255> - Medium to large words become cooldown for few seconds, zero points for them until after</colour>
	<colour=255,255,100,255> - Same word many times is lowered score.</colour>
	<colour=100,255,100,255> - Any order is for words ok ;)</colour>
	<colour=100,255,100,255> - Punctuate your words if want to be fancy is ok (?,':;)</colour>

	<colour=255,100,255,255> Words is make you seen for a little time, so if careful pay attention of another player, they find you!</colour>
	<colour=255,100,255,255> Last player standing wins! </colour>
	</font>


	<font=HelpRow><colour=255,255,200,255>bind_gm_showhelp</colour> : Show/hide this help screen</font>
	<font=HelpRow><colour=255,255,200,255>bind_gm_showteam</colour> : Change your player model and colors</font>
	opt_outfitter



	<font=HelpSubTitle>Credits:</font>
	<font=HelpDetails>Playtesters:</font>
	<colour=200,200,200,255>
	<font=HelpRow> - Muffin/ashii</font>
	<font=HelpRow> - Foohy</font>
	<font=HelpRow> - Lyo</font>
	<font=HelpRow> - An Actual Hyena Named Sitkero</font>
	</colour>
]]

HelpText = HelpText:gsub("opt_outfitter", function(x)
	if concommand.GetTable()["outfitter"] then
		return "<font=HelpRow><colour=255,255,200,255>bind_gm_showspare1</colour> : Show outfitter screen (workshop playermodels)</font>"
	else
		return ""
	end
end)

HelpText = HelpText:gsub("bind_([%w%d_]+)", function(x) return input.LookupBinding( x ) end)

local HelpTextMarkup = markup.Parse( HelpText )

--[[local HelpDemos = {
	wordm_phrasescore.New( LocalPlayer(), {
		phrase = "This gaem is fun",
		words = {
			{
				flags = WORD_VALID,
				first = 1,
				last = 4,
				score = 4,
			},
			{
				flags = 0,
				first = 6,
				last = 9,
				score = 0,
			},
			{
				flags = WORD_VALID,
				first = 11,
				last = 12,
				score = 2,
			},
		}
	})
}]]

function GM:DrawHelp()

	if not self.bShowingHelp then return end

	surface.SetDrawColor(0, 0, 0, 180)
	surface.DrawRect(0,0,ScrW(),ScrH())

	HelpTextMarkup:Draw(100, 100, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) 

	--HelpDemos[1]:Draw(120,600,true)

end