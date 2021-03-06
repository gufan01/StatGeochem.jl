## --- Read ESRI Arc/Info ASCII grid files

    function parse_AAIGrid(fname, parseType)
        # Open the file
        fid = open(fname)

        metadata = Dict()
        metadata["ncols"] = parse(match(r"  *(.*?)$", readline(fid))[1])
        metadata["nrows"] = parse(match(r"  *(.*?)$", readline(fid))[1])
        metadata["xll_corner"] = parse(match(r"  *(.*?)$", readline(fid))[1])
        metadata["yll_corner"] = parse(match(r"  *(.*?)$", readline(fid))[1])
        metadata["cellsize"] = parse(match(r"  *(.*?)$", readline(fid))[1])
        metadata["nodata"] = parse(match(r"  *(.*?)$", readline(fid))[1])

        nrows = metadata["nrows"]
        ncols = metadata["ncols"]

        data = Array{Int16}(undef,ncols,nrows)
        for i = 1:nrows
            l = readline(fid)
            delim_string_parse!(data, l, ' ', Int16, offset=(i-1)*ncols)
        end

        # Close the file
        close(fid)

        return (data', metadata)
    end
    export parse_AAIGrid

## --- Calculate slope from a DEM

    function max_slope_earth(matrix, x_lon_cntr, y_lat_cntr, cellsize; minmatval=-12000)
        # Returns slope in units/kilometer given a latitude-longitude grid of z-values

        # Allocate output array
        slope = Array{UInt16}(undef,size(matrix))

        # Average size of a degree on Earth
        km_per_lat = 111.1

        # Fill in the center first
        distNS = 2 * cellsize * km_per_lat
        for i = 2:(size(matrix,1)-1)
            # Distance between grid cell centers
            km_per_lon = cos(y_lat_cntr[i] * pi/180) * km_per_lat
            distEW = 2 * cellsize * km_per_lon
            distDiag = sqrt(distNS^2 + distEW^2)

            for j = 2:(size(matrix,2)-1)
                # Gradients, in matrix units per km
                if matrix[i,j] < minmatval
                    slope[i,j] = 0
                else
                    if (matrix[i+1,j] < minmatval) || (matrix[i-1,j] < minmatval)
                        NS = 0
                    else
                        NS = abs(matrix[i+1,j] - matrix[i-1,j]) / distNS
                    end
                    if (matrix[i,j+1] < minmatval) || (matrix[i,j-1]<minmatval)
                        EW = 0
                    else
                        EW = abs(matrix[i,j+1] - matrix[i,j-1]) / distEW
                    end
                    if (matrix[i+1,j-1] < minmatval) || (matrix[i-1,j+1] < minmatval)
                        NESW = 0
                    else
                        NESW = abs(matrix[i+1,j-1] - matrix[i-1,j+1]) / distDiag
                    end
                    if (matrix[i+1,j+1] < minmatval) || (matrix[i-1,j-1] < minmatval)
                        NWSE = 0
                    else
                        NWSE = abs(matrix[i+1,j+1] - matrix[i-1,j-1]) / distDiag
                    end

                    # Record the steepest slope
                    slope[i,j] = round(UInt16, min(max(max(NS,EW), max(NESW,NWSE)), 0xffff))
                end
            end

            # Fill in edges too
            distEW = cellsize * km_per_lon
            distDiag = sqrt((distNS/2)^2 + distEW^2)

            # Left edge
            if (matrix[i+1,1] < minmatval) || (matrix[i-1,1] < minmatval)
                NS = 0
            else
                NS = abs(matrix[i+1,1] - matrix[i-1,1]) / distNS
            end
            if (matrix[i,2] < minmatval) || (matrix[i,1] < minmatval)
                EW = 0
            else
                EW = abs(matrix[i,2] - matrix[i,1]) / distEW
            end
            if (matrix[i+1,1] < minmatval) || (matrix[i-1,2] < minmatval)
                NESW = 0
            else
                NESW = abs(matrix[i+1,1] - matrix[i-1,2]) / distDiag
            end
            if (matrix[i+1,2] < minmatval) || (matrix[i-1,1] < minmatval)
                NWSE = 0
            else
                NWSE = abs(matrix[i+1,2] - matrix[i-1,1]) / distDiag
            end
            slope[i,1] = round(UInt16, min(max(max(NS,EW), max(NESW,NWSE)), 0xffff))

            # Right edge
            if (matrix[i+1,end] < minmatval) || (matrix[i-1,end] < minmatval)
                NS = 0
            else
                NS = abs(matrix[i+1,end] - matrix[i-1,end]) / distNS
            end
            if matrix[i,end]<minmatval || matrix[i,end-1]<minmatval
                EW = 0
            else
                EW = abs(matrix[i,end] - matrix[i,end-1]) / distEW
            end
            if (matrix[i+1,end-1] < minmatval) || (matrix[i-1,end] < minmatval)
                NEWS = 0
            else
                NESW = abs(matrix[i+1,end-1] - matrix[i-1,end]) / distDiag
            end
            if (matrix[i+1,end] < minmatval) || (matrix[i-1,end-1] < minmatval)
                NWSE = 0
            else
                NWSE = abs(matrix[i+1,end] - matrix[i-1,end-1]) / distDiag
            end
            slope[i,end] = round(UInt16, min(max(max(NS,EW), max(NESW,NWSE)), 0xffff))
        end

        # Fill in the top and bottom row
        distNS = cellsize * km_per_lat

        # Top row
        km_per_lon = cos(y_lat_cntr[1]*pi/180) * km_per_lat
        distEW = 2*cellsize*km_per_lon
        distDiag = sqrt(distNS^2+(distEW/2)^2)

        for j = 2:(size(matrix,2)-1)
            # Gradients, in meters per km
            if (matrix[2,j] < minmatval) || (matrix[1,j] < minmatval)
                NS = 0
            else
                NS = abs(matrix[2,j] - matrix[1,j]) / distNS
            end
            if (matrix[1,j+1] < minmatval) || (matrix[1,j-1] < minmatval)
                EW = 0
            else
                EW = abs(matrix[1,j+1] - matrix[1,j-1]) / distEW
            end
            if (matrix[2,j-1] < minmatval) || (matrix[1,j] < minmatval)
                NESW = 0
            else
                NESW = abs(matrix[2,j-1] - matrix[1,j]) / distDiag
            end
            if (matrix[2,j+1] < minmatval) || (matrix[1,j] < minmatval)
                NWSE = 0
            else
                NWSE = abs(matrix[2,j+1] - matrix[1,j]) / distDiag
            end
            slope[1,j] = round(UInt16, min(max(max(NS,EW), max(NESW,NWSE)), 0xffff))
        end
        slope[1,1] = 0
        slope[1,end] = 0

        # Bottom row
        km_per_lon = cos(y_lat_cntr[end] * pi/180) * km_per_lat
        distEW = 2 * cellsize * km_per_lon
        distDiag = sqrt(distNS^2 + (distEW/2)^2)
        for j = 2:(size(matrix,2)-1)
            # Gradients, in meters per Km
            if (matrix[end-1,j] < minmatval) || (matrix[end,j] < minmatval)
                NS = 0
            else
                NS = abs(matrix[end-1,j] - matrix[end,j]) / distNS
            end
            if (matrix[end,j+1] < minmatval) || (matrix[end,j-1] < minmatval)
                EW = 0
            else
                EW = abs(matrix[end,j+1] - matrix[end,j-1]) / distEW
            end
            if (matrix[end-1,j-1] < minmatval) || (matrix[end,j] < minmatval)
                NESW = 0
            else
                NESW = abs(matrix[end-1,j-1] - matrix[end,j]) / distDiag
            end
            if (matrix[end-1,j+1] < minmatval) || (matrix[end,j] < minmatval)
                NWSE = 0
            else
                NWSE = abs(matrix[end-1,j+1] - matrix[end,j]) / distDiag
            end
            slope[end,j] = round(UInt16, min(max(max(NS,EW), max(NESW,NWSE)), 0xffff))
        end
        slope[end,1] = 0
        slope[end,end] = 0

        return slope
    end
    export max_slope_earth

    function ave_slope_earth(matrix, x_lon_cntr, y_lat_cntr, cellsize; minmatval=-12000, maxmatval=9000)
        # Returns slope in units/kilometer given a latitude-longitude grid of z-values

        # Allocate intermediate and output arrays
        distance = Array{Float64}(undef,8)
        local_slopes = Array{Float64}(undef,8)
        slope = Array{UInt16}(undef,size(matrix))

        # Index offsets to cycle through:
        #         [N,NE,E,SE,S,SW,W,NW]
        ioffset = [-1,-1,0,1,1,1,0,-1]
        joffset = [0,1,1,1,0,-1,-1,-1]
        #
        # i.e. Layout:
        # 8 1 2
        # 7 x 3
        # 6 5 4

        # Average size of a degree on Earth
        km_per_lat = 111.1

        # Distance between grid cell centers
        # N, S
        distance[[1,5]] .= cellsize * km_per_lat

        # Fill in the center first
        for i = 2:(size(matrix,1)-1)
            # Distance between grid cell centers
            km_per_lon = cos(y_lat_cntr[i]*pi/180) * km_per_lat
            distance[[3,7]] .= cellsize*km_per_lon; #E, W
            distance[[2,4,6,8]] .= sqrt(distance[1]^2+distance[3]^2)  # Diagonals

            # Center
            for j = 2:(size(matrix,2)-1)
                # Gradients, in matrix z-units per km
                here = matrix[i,j]
                if (here < minmatval) || (here > maxmatval)
                    slope[i,j] = 0
                else
                    for k = 1:8
                        there = matrix[i+ioffset[k], j+joffset[k]]
                        if (there < minmatval) || (there > maxmatval)
                            local_slopes[k] = 0
                        else
                            local_slopes[k] = abs(there-here) / distance[k]
                        end
                    end
                    # Record the average slope
                    slope[i,j] = round(UInt16, min(mean(local_slopes), 0xffff))
                end
            end

            # Left edge
            here = matrix[i,1]
            if (here < minmatval) || (here > maxmatval)
                slope[i,1] = 0
            else
                for k = 1:5
                    there = matrix[i+ioffset[k], 1+joffset[k]]
                    if (there < minmatval) || (there > maxmatval)
                        local_slopes[k] = 0
                    else
                        local_slopes[k] = abs(there-here) / distance[k]
                    end
                end
                slope[i,1] = round(UInt16, min(mean(local_slopes[1:5]), 0xffff))
            end

            # Right edge
            here = matrix[i,end]
            if (here < minmatval) || (here > maxmatval)
                slope[i,end] = 0
            else
                for k = [5,6,7,8,1]
                    there = matrix[i+ioffset[k], end+joffset[k]]
                    if (there < minmatval) || (there > maxmatval)
                        local_slopes[k] = 0
                    else
                        local_slopes[k] = abs(there-here) / distance[k]
                    end
                end
                slope[i,end] = round(UInt16, min(mean(local_slopes[[5,6,7,8,1]]), 0xffff))
            end
        end

        # Top row
        km_per_lon = cos(y_lat_cntr[1] * pi/180) * km_per_lat
        distance[[3,7]] .= cellsize * km_per_lon #E, W
        distance[[2,4,6,8]] .= sqrt(distance[1]^2 + distance[3]^2)  # Diagonals
        for j = 2:(size(matrix,2)-1)
            # Gradients, in matrix units per km
            here = matrix[1,j]
            if (here < minmatval) || (here > maxmatval)
                slope[1,j] = 0
            else
                for k=3:7
                    there = matrix[1+ioffset[k], j+joffset[k]]
                    if (there < minmatval) || (there > maxmatval)
                        local_slopes[k] = 0
                    else
                        local_slopes[k] = abs(there-here) / distance[k]
                    end
                end
                slope[1,j] = round(UInt16, min(mean(local_slopes[3:7]), 0xffff))
            end
        end
        slope[1,1] = 0
        slope[1,end] = 0

        # Bottom row
        km_per_lon = cos(y_lat_cntr[end] *pi/180) * km_per_lat
        distance[[3,7]] .= cellsize * km_per_lon #E, W
        distance[[2,4,6,8]] .= sqrt(distance[1]^2+distance[3]^2)  # Diagonals
        for j = 2:(size(matrix,2)-1)
            # Gradients, in matrix units per km
            here = matrix[end,j]
            if (here < minmatval) || (here > maxmatval)
                slope[end,j] = 0
            else
                for k = [7,8,1,2,3]
                    there = matrix[end+ioffset[k], j+joffset[k]]
                    if (there < minmatval) || (there > maxmatval)
                        local_slopes[k] = 0
                    else
                        local_slopes[k] = abs(there-here) / distance[k]
                    end
                end
                slope[end,j] = round(UInt16, min(mean(local_slopes[[7,8,1,2,3]]),0xffff));
            end
        end
        slope[end,1] = 0
        slope[end,end] = 0

        return slope
    end
    export ave_slope_earth


## --- End of File
