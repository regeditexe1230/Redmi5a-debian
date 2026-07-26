# Redmi 5A (riva) Linux Kernel Build System
# Target: msm8917 / msm8937 / msm89x7 (ARM64)

KDIR := $(CURDIR)/linux-6.6
ARCH := arm64
CROSS_COMPILE := aarch64-linux-gnu-

# Auto-detect cross-compilation on non-ARM64 hosts
UNAME_M := $(shell uname -m)
ifneq ($(UNAME_M),aarch64)
    CROSS_PREFIX := CROSS_COMPILE=$(CROSS_COMPILE)
else
    CROSS_PREFIX :=
endif

# Out-of-tree modules to build
MODULES := camss_overlay mclk_fix test_i2c dapm_fix

.PHONY: all kernel modules image clean mrproper

all: kernel modules image
	@echo ""
	@echo "Build complete! Output: boot_new.img, modules/*.ko"

kernel:
	@echo "==> Building Linux $(shell head -3 $(KDIR)/Makefile | grep -E 'VERSION|PATCHLEVEL|SUBLEVEL' | tr '\n' ' ' | sed 's/VERSION = //;s/PATCHLEVEL = /./;s/SUBLEVEL = /./;s/EXTRAVERSION =.*//')kernel..."
	@if [ ! -f $(KDIR)/.config ]; then \
		echo "No .config found, generating from config_redmi2.gz..."; \
		zcat config_redmi2.gz > $(KDIR)/.config; \
	fi
	$(MAKE) -C $(KDIR) ARCH=$(ARCH) $(CROSS_PREFIX) olddefconfig
	$(MAKE) -C $(KDIR) ARCH=$(ARCH) $(CROSS_PREFIX) -j$$(nproc)
	@echo "Kernel built: $(KDIR)/arch/arm64/boot/Image.gz"

modules:
	@echo "==> Building out-of-tree modules..."
	@for dir in $(MODULES); do \
		echo "  [$$dir]"; \
		$(MAKE) -C $(KDIR) ARCH=$(ARCH) $(CROSS_PREFIX) M=$(CURDIR)/modules/$$dir modules || exit 1; \
	done
	@echo "Modules built in modules/*/"

image:
	@echo "==> Creating boot image..."
	@if [ ! -f $(KDIR)/arch/arm64/boot/Image.gz ]; then \
		echo "ERROR: Kernel not built. Run 'make kernel' first."; \
		exit 1; \
	fi
	python3 mkimg.py
	@echo "boot_new.img created ($(shell ls -lh boot_new.img | awk '{print $$5}'))"

clean:
	@echo "==> Cleaning kernel..."
	$(MAKE) -C $(KDIR) clean
	@echo "==> Cleaning modules..."
	@for dir in $(MODULES); do \
		$(MAKE) -C $(KDIR) M=$(CURDIR)/modules/$$dir clean 2>/dev/null || true; \
	done
	rm -f boot_new.img

mrproper: clean
	$(MAKE) -C $(KDIR) mrproper

help:
	@echo "Redmi 5A Kernel Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Build kernel, modules, and boot image (default)"
	@echo "  kernel    - Build Linux 6.6 kernel for ARM64"
	@echo "  modules   - Build out-of-tree kernel modules"
	@echo "  image     - Create boot_new.img (Android boot image format)"
	@echo "  clean     - Remove build artifacts"
	@echo "  mrproper  - Deep clean (removes .config too)"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - aarch64-linux-gnu-gcc (cross-compiler)"
	@echo "  - python3 (for mkimg.py)"
