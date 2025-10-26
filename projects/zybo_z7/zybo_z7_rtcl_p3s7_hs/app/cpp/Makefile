
TARGET = zybo_z7_rtcl_p3s7_hs.out

CFLAGS  += -Wall -g -O0 `pkg-config --cflags opencv4` -I../../../../../jelly/include
LDFLAGS += `pkg-config --libs opencv4`

OBJS = main.o

.PHONY: all
all: build

.PHONY: build
build: $(TARGET)

.PHONY: clean
clean:
	rm -rf $(TARGET) $(OBJS)

.PHONY: run
run: $(TARGET)
	./$(TARGET)

$(TARGET): $(OBJS)
	g++ -o $(TARGET) $(OBJS) $(LDFLAGS)

%.o : %.cpp
	g++ $(CFLAGS) -c $< -o $@
