all: image

image:
	docker build -t fetep/devshell "$(CURDIR)"
