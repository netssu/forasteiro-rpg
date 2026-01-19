local module = {
	Harpoon = 106096609898803,
	Brain = 106096609898803
}

module.getAnimationId = function(name)
	local id = module[name]
	if not id then
		warn(`[AnimationIds] Invalid animation name: {name}`)
		return nil
	end
	
	return id
end

return module
