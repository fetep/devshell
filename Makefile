all: image

image:
	nix-build devshell.nix
	docker load < result
