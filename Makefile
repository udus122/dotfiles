# Run all shell files
all:link init brew

# run init.sh
init:
	@echo "\033[0;34mRun init.sh\033[0m"
	@./init.sh
	@echo "\033[0;34mDone.\033[0m"

# next create symbolic links
link:
	@echo "\033[0;34mRun link.sh\033[0m"
	@./link.sh
	@echo "\033[0;34mDone.\033[0m"

# install macOS packages and applications.
install:
	@echo "\033[0;34mRun install.sh\033[0m"
	@./install.sh
	@echo "\033[0;32mDone.\033[0m"
