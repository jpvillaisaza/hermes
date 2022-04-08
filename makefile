.PHONY: build
build:
	cd docs/ && bundle exec jekyll build

.PHONY: clean
clean:
	cd docs/ && bundle exec jekyll clean

.PHONY: serve
serve:
	cd docs/ && bundle exec jekyll serve
