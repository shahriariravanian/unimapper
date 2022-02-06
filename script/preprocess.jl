using ZfpCompression
using JSON
using Statistics

function compress_cube(path, name, cubes::Array{UInt8,3}...; precision=10)
    c = [Float32.(cube) / 256f0 for cube in cubes]
    return compress_cube(path, name, c...; precision)
end

function compress_cube(path, name, cubes::Array{T,3}...; precision=10) where T <: Real
    if any(x->size(x)!=size(cubes[1]), cubes[2:end])
        error("all cubes should have the same size")
    end

    nx, ny, frames = size(cubes[1])

    channels = [compress_channel(cube, path * "_$i.zfp"; precision) for (i,cube) in enumerate(cubes)]

    D = Dict(
        "version" => "1.0",
        "eltype" => "float32",
        "name" => name,
        "nx" => nx,
        "ny" => ny,
        "frames" => frames,
        "channels" => channels,
    )

    json_path = path * ".json"
    fd = open(json_path, "w")
    JSON.print(fd, D, 4)
    close(fd)

    return D
end

function compress_channel(cube::Array{T,3}, path; precision=10) where T <: Real
    nx, ny, frames = size(cube)
    nz = (min(2^21 ÷ (nx*ny), frames) ÷ 4) * 4

    v = Float32.(cube)
    segs = segment(frames, nz)

    L = Int[]

    fd = open(path, "w")

    for s in segs
        stream = zfp_compress(v[:,:,s[1]:s[1]+s[2]-1]; precision, write_header=false)
        println(Int.(stream[1:10]))
        push!(L, length(stream))
        write(fd, stream)
    end

    close(fd)

    d = [Dict(
            "t0" => s[1]-1,
            "t1" => s[1]+s[2]-1,
            "s0" => sum(L[1:i-1]; init=0),
            "s1" => sum(L[1:i]))
        for (i,s) in enumerate(segs)]


    μ, σ = find_stretch_function(v)

    return Dict(
        "precision" => precision,
        "tol" => 0,
        "rate" => 0,
        "path" => path,
        "segments" => d,
        "tanh_loc" => Float32(μ),
        "tanh_scale" => Float32(σ)
    )
end

############################### Utilities ####################################

function segment(frames, nz)
    n = []
    m = 1

    while m <= frames
        l = min(nz, frames + 1 - m)
        push!(n, (m, l))
        m += l
    end

    return n
end


function find_stretch_function(v)
    μ = mean(v)
    σ = std(v)
    return μ, σ
end

function normalize_data(data::AbstractArray{T,3}) where T <: Real
    nx, ny, frames = size(data)
    cube = zeros(Float32, size(data))

    for y = 1:ny
        for x = 1:nx
            u = data[x, y, :]
            a = minimum(u)
            b = maximum(u)
            cube[x, y, :] .= (u .- a) ./ (b - a)
        end
    end

    return cube
end

################################ Test ########################################

function test()
    data = zeros(UInt16, (128,128,1000))
    fd = open("2022-01-23_Exp000_Rec020.bin", "r")
    read!(fd, data)
    close(fd)

    # cube also needs to be temporally and spatially filtered
    cube = normalize_data(data)
    compress_cube("./2022-01-23_Exp000_Rec020", "2022-01-23_Exp000_Rec020", cube)
end
