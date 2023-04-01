module SimpleCI

using HumanReadableSExpressions
using StructTypes
import StructTypes: StructType

abstract type Step end
StructTypes.StructType(::Type{Step}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Step}) = :type
StructTypes.subtypes(::Type{Step}) = (gradle=GradleStep,shell=ShellStep)

struct GradleStep <: Step
    type::String
    name::String
    tasks::Vector{String}
    workingdir::String
end

function StructTypes.construct(::Type{GradleStep}, type, name, tasks, workingdir)
    GradleStep(type, name, tasks, something(workingdir, "."))
end
StructTypes.StructType(::Type{GradleStep}) = StructTypes.Struct()

name(x::GradleStep) = x.name
workingdir(x::GradleStep) = x.workingdir
function runstep(step::GradleStep)
    run(`./gradlew $(join(step.tasks, ' '))`)
end

struct ShellStep <: Step
    type::String
    name::String
    script::String
    workingdir::String
end

function StructTypes.construct(::Type{ShellStep}, type, name, script, workingdir)
    ShellStep(type, name, script, something(workingdir, "."))
end
StructTypes.StructType(::Type{ShellStep}) = StructTypes.Struct()

name(x::ShellStep) = x.name
workingdir(x::ShellStep) = x.workingdir
function runstep(step::ShellStep)
    run(`$(step.script)`)
end

struct Config
    steps::Vector{Step}
end

StructTypes.StructType(::Type{Config}) = StructTypes.Struct()

function main(; configpath = ".simpleci.jl/config.hrse")
    config = readhrse(configpath, type = Config)
    rootdir = pwd()
    for step in config.steps
        println("Running step $(name(step))...")
        cd(joinpath(rootdir, workingdir(step)))
        runstep(step)
    end
end

end # module SimpleCI
