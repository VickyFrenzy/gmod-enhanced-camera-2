GMOD_PATH = $(HOME)/.steam/steam/steamapps/common/GarrysMod
GMAD = $(GMOD_PATH)/bin/gmad_linux
GMPUBLISH = env LD_LIBRARY_PATH=$(GMOD_PATH)/bin $(GMOD_PATH)/bin/gmpublish_linux

GMA_SRC = $(shell find lua -type f -name '*.lua')
ICON_SRC = icon.xcf
TXT_SRC = README.md

TARGET = enhanced_camera
WORKSHOP_ID = 678037029

all: $(TARGET).gma $(TARGET).jpg $(TARGET).txt

$(TARGET).gma: $(GMA_SRC)
	$(GMAD) create -folder . -out $@

$(TARGET).jpg: $(ICON_SRC)
	convert $< -layers flatten $@

$(TARGET).txt: $(TXT_SRC)
	md2steam < $< > $@

publish: $(TARGET).gma $(TARGET).jpg
ifeq ($(WORKSHOP_ID),)
	$(GMPUBLISH) create -addon $(TARGET).gma -icon $(TARGET).jpg
else
	$(GMPUBLISH) update -id $(WORKSHOP_ID) -addon $(TARGET).gma -icon $(TARGET).jpg
endif

clean:
	rm -f $(TARGET).gma $(TARGET).jpg $(TARGET).txt

.PHONY: all publish clean
