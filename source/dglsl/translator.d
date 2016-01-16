
module dglsl.translator;

import std.range;
import std.string;


import dglsl.type;
import dglsl.sampler;
import dglsl.shader;




string dtoglsl(Shader)() {
    import std.traits;
    import std.string;
    import std.algorithm;
    string result = "#version %s\n".format(Shader.glsl);
    string[] functions;


    static if (Shader.type == "geometry") {
        static assert(__traits(hasMember, Shader, "_input"));
        static assert(__traits(hasMember, Shader, "_output"));
        static assert(__traits(hasMember, Shader, "gl_in"));

        auto input = getUDAs!(Shader._input, layout)[0];
        result ~= "layout(%s) in;\n".format(input.qualifier);
        auto o = getUDAs!(Shader._output, layout)[0];
        result ~= "layout(%s, max_vertices = %d) out;\n".format(o.qualifier, o.maxVertices.value);

        alias gl_in = typeof(Shader.gl_in[0]);
        result ~= "in " ~ gl_in.stringof ~ " {\n";
        foreach (immutable s; __traits(derivedMembers, gl_in)) {
            result ~= "\t%s %s;\n".format(glslType!(typeof(__traits(getMember, gl_in, s))), s);
        }
        result ~= "};\n";

        foreach (immutable s; __traits(derivedMembers, Shader)) {
            static if (s != typeof(Shader.gl_in[0]).stringof && !hasUDA!(__traits(getMember, Shader, s), ignore)) {
                alias t = typeof(__traits(getMember, Shader, s));
                static if(is(t == function)) {
                    functions ~= s;
                } else static if (s != "_input" && s != "_output") {
                    static if (hasUDA!(__traits(getMember, Shader, s), uniform)) {
                        result ~= "uniform ";
                    }

                    static if (hasUDA!(__traits(getMember, Shader, s), output)) {
                        result ~= "out ";
                    }

                    result ~= "%s %s;\n".format(glslType!(typeof(__traits(getMember, Shader, s))), s);
                }
            }
        }
    } else {
        foreach (immutable s; __traits(derivedMembers, Shader)) {
            static if (!hasUDA!(__traits(getMember, Shader, s), ignore)) {
                static if(is(typeof(__traits(getMember, Shader, s)) == function)) {
                    functions ~= s;
                } else {
                    static if (hasUDA!(__traits(getMember, Shader, s), input)) {
                        result ~= "in ";
                    }

                    static if (hasUDA!(__traits(getMember, Shader, s), output)) {
                        result ~= "out ";
                    }

                    static if (hasUDA!(__traits(getMember, Shader, s), uniform)) {
                        result ~= "uniform ";
                    }

                    result ~= "%s %s;\n".format(glslType!(typeof(__traits(getMember, Shader, s))), s);
                }
            }
        }
    }

    auto source = import(Shader.filepath).lineSplitter.drop(Shader.lineno - 1);
    int level = 0;
    while (!source.empty && level >= 0) {
        string line = source.front;

        if (functions.any!(s => line.canFind(s))) {
            int lvl = level;
            while (!source.empty) {
                if (source.front.canFind('{')) level++;
                if (source.front.canFind('}')) {
                    level--;
                    if (level < lvl) break;
                }
                result ~= source.front ~ "\n";
                source.popFront();
            }
            
            continue;
        }

        if (line.canFind('{')) level++;
        if (line.canFind('}')) level--;
        
        source.popFront();
    }

    return result;
}