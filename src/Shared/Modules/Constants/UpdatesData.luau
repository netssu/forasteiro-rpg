local UpdateData = {}

-- VARIABLES
UpdateData.List = {
	{
		Title = "Update 1.2",
		Phrase = "- Test version",
		TitleSize = 25,
		PhraseSize = 18
	},

}

-- FUNCTIONS
function UpdateData.GetUpdates()
	return UpdateData.List
end

return UpdateData
