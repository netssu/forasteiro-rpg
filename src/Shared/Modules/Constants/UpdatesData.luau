local UpdateData = {}

-- VARIABLES
UpdateData.List = {
	{
		Title = "Update 1.2 - The Beginning",
		Phrase = "We added the inventory system.",
		TitleColor = Color3.fromRGB(255, 0, 0),
		TitleSize = 25,
		PhraseColor = Color3.fromRGB(0, 0, 0),
		PhraseSize = 18
	},

}

-- FUNCTIONS
function UpdateData.GetUpdates()
	return UpdateData.List
end

return UpdateData
