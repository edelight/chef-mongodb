class Chef::ResourceDefinitionList::MongoDB
  # Returns an array of snapshot ids that represent the latest consistent 
  # snapshot of the N raided <volumes>.  Each volume's snapshot description is
  # expected to have the form "Mongo RAID Snapshot <timestamp> <disk_number>".
  # A set of snapshots are considered consistent if they share the timestamp in
  # the description.  If no such group of snapshots are found, this returns
  # nil.  The returned snapshots array will be parallel to the volumes array,
  # i.e the latest snapshot for the Nth volume in the array will be the Nth
  # snapshot in the result.
  def self.find_snapshots(key, secret_key, volumes, clustername)
    require 'aws-sdk'

    if volumes.size == 0
      Chef::Log.info "No reference volumes given.  Returning empty list."
      return []
    end

    # Compute the latest snapshots.
    ec2 = AWS::EC2.new(
          :access_key_id => key,
          :secret_access_key => secret_key)

    # This is an array of arrays.  snapshots[i] will have the sorted list of
    # snapshots for volumes[i].  The snapshots are sorted by description which
    # has the snapshot timestamp in it, so the snapshots will be sorted in
    # ascending order of timestamp.
    snapshots = []

    # We put all of this logic in a memoize block so each fetch of a snapshot
    # attribute will not result in a network connection.
    AWS.memoize do
      for volume_id in volumes
        # Get the list of snapshots for the currenet volume.
        vol_snapshots = ec2.snapshots.select { |s| s.volume_id == volume_id }
        vol_snapshots.sort! { |x, y| x.description <=> y.description }
        # Remove the incomplete snapshots.  This makes the assumption that
        # later snapshots will not finish before earlier snapshots.
        while not vol_snapshots.size == 0 and
              vol_snapshots.last.status != :completed
          vol_snapshots.pop
        end
        snapshots.push vol_snapshots
      end
      Chef::Log.info "Found the list of snapshots"
        r = /Mongo RAID (Snaphsot|Snapshot) ([^ ]+) ([[:digit:]]+)/
      match_found = false
      # Now we need to find the last complete set of snapshots.  This is done 
      # by parsing the timestamp from the description of the newest snapshot
      # for each volume (snapshots[i].last) and seeing if they are all the same.
      # If they aren't, we pop the snapshot with the newest timestamp and 
      # try again.  If any of the volumes has no more snapshots, then we don't
      # have a consistent snapshot, so we return nil.
      while not match_found
        if snapshots[0].size == 0
          return nil
        end
        # Keep track of the index of the snapshot array that has the
        # description which is lexicographically the greatest. This should
        # also be the newest snapshot created.
        largest = 0
        date = r.match(snapshots[0].last.description)[2]
        match_found = true

        # Iterate over the newest snapshot for other volumes to see if the date
        # matches the first one.
        for i in 1..(snapshots.size() - 1)
          if snapshots[i].size == 0
            return nil
          end

          if snapshots[largest].last.description < snapshots[i].last.description
            largest = i
          end

          if r.match(snapshots[i].last.description)[2] != date
            match_found = false
          end
        end

        if not match_found
          snapshots[largest].pop
        end
      end
      if match_found
        Chef::Log.info "Starting from #{snapshots[0].last.description}"
        return snapshots.map { |list| list.pop.id }
      end
    end
  end
end
