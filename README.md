[![Build Status](https://travis-ci.org/walaj/pthread-lite.svg?branch=master)](https://travis-ci.org/walaj/pthread-lite)

## *pthread-lite* Light-weight header library for C++ concurrency with pthread

*pthread-lite* is a modification of ``wqueue.h`` by Victor Hargrove. It unites the
consumer thread class and work item class into a single header file. It also adds
a template parameter to the consumer thread class to allow for thread-specific
data (e.g. store results computed on a single thread, thread-private file
pointer to avoid thread-collisions when randomly accessing files such as 
BAM files).

### Example
```C++
#include "pthread-lite.h"
#include <vector>
#include <cstring>
#include <cstdlib>
#include <iostream>

/** Define a thread-item class to hold data, etc private
* to each thread. For instance, this can store output from a thread that
* can be dumped to a file after all processing is done. This is useful
* because writing to a file in a multi-threaded program requires a mutex lock,
* thus halting work on other threads. Alternatively useful for holding a pointer
* for random access to a file, so multiple threads can randomly access the same file
*/
struct MyThreadItem {
  
  MyThreadItem(size_t i) : id(i), hit_counts(0) {}
  
  // example accessor for storing results for this thread
  void AddHits(size_t new_hits) { hit_counts += new_hits; } 

  size_t id; // id to identify thread	

  // include any number of thread-specific data below
  size_t hit_counts; // results from all jobs processed on this thread
};


/** Define a work-item class to hold data for specific task
 * (e.g. some operation on a set of sequences stored in char array)
 */
class MyWorkItem {

  public:
  MyWorkItem(char* data, size_t len) : m_data(data), m_len(len) {}
    
    // define the actual work to be done
    bool runStringProcessing(MyThreadItem* thread_data) {
      // do something with the data ... (silly example here)
      size_t results = 0;
      if (m_data) 
	for (size_t n = 0; n < 1000; ++n) 
	  for (size_t i = 0; i < m_len; ++i)
	    if (m_data[i] == 'a')
	      ++results;
      thread_data->AddHits(results);   // store the results in the thread-level store
      
      if (m_data) free(m_data);        // done with this unit, so clear data
    }   

    // always include a run function that takes only
    // a thread-item and returns bool
    bool run(MyThreadItem* thread_data) {
      // do the actual work
      return runStringProcessing(thread_data);
    }      

  private:

    // some chunk of data to be processed as one unit on one thread
    char * m_data;
    size_t m_len;

};

int main() {	

  // create the work item queue and consumer threads    	   	
  WorkQueue<MyWorkItem*>  queue; // queue of work items to be processed by threads
  std::vector<ConsumerThread<MyWorkItem, MyThreadItem>* > threadqueue;

  // add 1000 work jobs to the WorkQueue
  for (int i = 0; i < 5000; ++i) {

    // establish some chunk of data...
    const size_t len = 5000;
    char * data = (char*)malloc(len + 1); 
    for (size_t j = 0; j < len; ++j)
      data[j] = 'a';
    data[len] = '\0';

    // add to work item and then to queue for processing
    // must be on heap, since dealloc is done inside ConsumerThread
    MyWorkItem * wu = new MyWorkItem(data, len);
    queue.add(wu);    
  } 

  // establish and start the threads
  size_t num_cores = 2;
  for (int i = 0; i < num_cores; ++i) {
    MyThreadItem * tu  = new MyThreadItem(i);  // create the thread-specific data, must be on heap.
    ConsumerThread<MyWorkItem, MyThreadItem>* threadr =        // establish new thread to draw from queue
      new ConsumerThread<MyWorkItem, MyThreadItem>(queue, tu); // always takes WorkQueue and some thread item
    threadr->start(); 
    threadqueue.push_back(threadr); // add thread to the threadqueue
  }

  // wait for the threads to finish
  for (int i = 0; i < num_cores; ++i) 
    threadqueue[i]->join();

  // display the results
  for (int i = 0; i < num_cores; ++i) {
    const MyThreadItem * td = threadqueue[i]->GetThreadData();
    std::cerr << "thread " << td->id << " results " << td->hit_counts << std::endl;
  }
  return 0;
}
```
