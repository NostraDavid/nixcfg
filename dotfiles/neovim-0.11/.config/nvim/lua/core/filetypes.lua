vim.filetype.add({
	extension = {
		templ = "templ",
		tfvars = "terraform-vars",
		xsl = "xsl",
		xslt = "xsl",
	},
	filename = {
		[".gitlab-ci.yml"] = "yaml.gitlab",
		[".gitlab-ci.yaml"] = "yaml.gitlab",
		["compose.yml"] = "yaml.docker-compose",
		["compose.yaml"] = "yaml.docker-compose",
		["docker-compose.yml"] = "yaml.docker-compose",
		["docker-compose.yaml"] = "yaml.docker-compose",
		["values.yml"] = "yaml.helm-values",
		["values.yaml"] = "yaml.helm-values",
	},
})

vim.treesitter.language.register("html", "templ")
vim.treesitter.language.register("hcl", "terraform-vars")
vim.treesitter.language.register("xml", "xsl")
vim.treesitter.language.register("yaml", "yaml.docker-compose")
vim.treesitter.language.register("yaml", "yaml.gitlab")
vim.treesitter.language.register("yaml", "yaml.helm-values")

return {}
