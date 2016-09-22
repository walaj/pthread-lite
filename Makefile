all: example.o
	g++ example.o -o example $(LIBS) -lpthread

example.o: example.cpp pthread-lite.h
	g++ -c example.cpp

.PHONY: clean

clean:
	rm -f example *.o
