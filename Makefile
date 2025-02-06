.PHONY: serve clean

serve:
	hugo serve --buildDrafts

clean:
	rm -rf public/ 