@rem Script to build Lua-5.1.* as static library under "Visual Studio .NET Command Prompt".
@rem Do not run from this directory; run it from the toplevel: etc\luavs.bat .
@rem It creates lua51.lib, lua.exe, and luac.exe in src.
@rem (contributed by David Manura and Mike Pall)

@setlocal
@set MYCOMPILE=cl /nologo /MT /O2 /W3 /c /D_CRT_SECURE_NO_DEPRECATE
@set MYLINK=link /nologo
@set MYLIB=lib /nologo
@set MYMT=mt /nologo

cd src
%MYCOMPILE% l*.c
del lua.obj luac.obj
%MYLIB% /out:lua51.lib l*.obj
%MYCOMPILE% lua.c
%MYLINK% /out:lua.exe lua.obj lua51.lib
%MYCOMPILE% l*.c print.c
del lua.obj linit.obj lbaselib.obj ldblib.obj liolib.obj lmathlib.obj^
    loslib.obj ltablib.obj lstrlib.obj loadlib.obj
%MYLINK% /out:luac.exe *.obj
del *.obj
cd ..
