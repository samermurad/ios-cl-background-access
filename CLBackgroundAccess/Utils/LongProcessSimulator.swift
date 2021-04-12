//
//  LongProcessSimulator.swift
//  CLBackgroundAccess
//
//  Created by Samer Murad on 11.04.21.
//

import Foundation


// MARK: - Declartions
/// Mock Class for simulating long running operations
class LongProcessSimulator {
    typealias JobId = Int
    typealias TickBlock = (_ progress: Int64, _ total: Int64, _ isDone: Bool) -> Bool?
    
    static let shared = LongProcessSimulator()
    
    private var jobs: [JobId: Bool] = [:]
    private var incremental = 1
    private var syncGroup = DispatchGroup()
    
    
    private init() {}
}


// MARK: - Jobs
extension LongProcessSimulator {
    private func newJob() -> JobId {
        defer {
            self.incremental += 1
            self.syncGroup.leave()
        }
        self.syncGroup.wait()
        self.syncGroup.enter()

        let job = JobId(self.incremental)
        self.jobs[job] = true
        return job
    }
    
    public func resetJobs() {
        defer {
            self.syncGroup.leave()
        }
        self.syncGroup.wait()
        self.syncGroup.enter()
        self.jobs = [:]
        self.incremental = 1
    }
    
    func isJobRunning(id: JobId) -> Bool {
        if let j = self.jobs[id] {
            return j
        }
        return false
    }

}

// MARK: - Tick Simulation
extension LongProcessSimulator {
    func tick(times: Int64, withRandomIntervals intervals: [TimeInterval] = [0.3, 0.7, 1], block: @escaping TickBlock) -> JobId {
        // get job id
        let id = newJob()
        // create new queue
        let queue = DispatchQueue(label: "LongProcessJob \(id)")
        // start async
        queue.async {
            var lastProgress = times
            for i in 1 ..< times {
                // get rndm seconds from intervals, default to 1 to avoid crashes
                let secs = intervals.randomElement() ?? 1
                // sleep for secs
                Thread.sleep(until: Date(timeIntervalSinceNow: secs))
                // call tick block
                if let cancel = block(i, times, false), cancel {
                    // job got cancelled
                    self.jobs[id] = false
                    lastProgress = i
                    break
                }
                
            }
            // last finishing call (discard return value)
            let _ = block(lastProgress, times, true)
            // clear job
            self.jobs.removeValue(forKey: id)
        }
        // return job is
        return id
    }
}
