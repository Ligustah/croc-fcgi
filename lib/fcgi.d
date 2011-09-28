module lib.fcgi;import tango.io.device.Conduit;import tango.io.Stdout;import tango.io.stream.Format;import tango.core.Exception;import tango.core.Array;import tango.sys.Environment;import tango.stdc.stringz;version(Windows){	pragma(lib, "Ws2_32.lib");}extern(C){	struct FCGX_Stream {		ubyte* rdNext;		ubyte* wrNext;		ubyte* stop;		ubyte* stopUnget;		int isReader;		int isClosed;		int wasFCloseCalled;		int FCGI_errno;		void* function(FCGX_Stream* stream) fillBuffProc;		void* function(FCGX_Stream* stream, int doClose) emptyBuffProc;		void* data;	}	alias char** FCGX_ParamArray;	int FCGX_Accept(FCGX_Stream** stdin, FCGX_Stream** stdout, FCGX_Stream** stderr, FCGX_ParamArray* envp);	int FCGX_GetStr(char* str, int n, FCGX_Stream* stream);	int FCGX_PutStr(char* str, int n, FCGX_Stream* stream);	int FCGX_HasSeenEOF(FCGX_Stream* stream);	int FCGX_FFlush(FCGX_Stream* stream);		int FCGI_Accept();}class FCGI_InputStream : InputStream{	FCGX_Stream* _inStream;		this(FCGX_Stream* inStream)	{		this._inStream = inStream;	}		size_t read(void[] dst)	{		return FCGX_GetStr(cast(char*)dst.ptr, dst.length, _inStream);	}		void[] load(size_t max = -1)	{		return Conduit.load(this, max);	}		InputStream input()	{		return this;	}		void close()	{		//ignored	}		long seek(long offset, Anchor anchor)	{		throw new IOException("operation not supported");	}		IConduit conduit()	{		return null;	}		typeof(this) flush()	{		return this;	}}class FCGI_OutputStream : OutputStream{	FCGX_Stream* _outStream;		this(FCGX_Stream* outStream)	{		this._outStream = outStream;	}		size_t write(void[] src)	{		return FCGX_PutStr(cast(char*)src.ptr, src.length, _outStream);	}		OutputStream copy(InputStream src, size_t max = -1)	{		Conduit.transfer(src, this, max);		return this;	}		void close()	{		//ignored	}		long seek(long offset, Anchor anchor)	{		throw new IOException("operation not supported");	}		IConduit conduit()	{		return null;	}		typeof(this) flush()	{		FCGX_FFlush(_outStream);		return this;	}		typeof(this) output()	{		return this;	}}class FCGI_Conduit : Conduit{	FCGX_Stream* _inStream, _outStream;	this(FCGX_Stream* inStream, FCGX_Stream* outStream)	{		this._inStream = inStream;		this._outStream = outStream;	}		size_t write(void[] src)	{		return FCGX_PutStr(cast(char*)src.ptr, src.length, _outStream);	}		size_t read(void[] dst)	{		return FCGX_GetStr(cast(char*)dst.ptr, dst.length, _inStream);	}	size_t bufferSize()	{		return 1024;	}	char[] toString()	{		return "FastCGIConduit";	}	void detach()	{		//do nothing here, stream is closed automatically	}}class FCGI_Request{	private FCGI_InputStream _in;	private FCGI_OutputStream _out, _err;	private char[][char[]] 	_params;		this(FCGX_Stream* input, FCGX_Stream* output, FCGX_Stream* error, FCGX_ParamArray params)	{		this._in = new FCGI_InputStream(input);		this._out = new FCGI_OutputStream(output);		this._err = new FCGI_OutputStream(error);						if(params != null)		{			for(; *params !is null; params++)			{				char[] p = fromStringz(*params);								size_t pos = p.find('=');				_params[p[0 .. pos]] = p[pos + 1 .. $];			}		}		else		{			_params = Environment.get();		}	}		public InputStream input()	{		return _in;	}		public OutputStream output()	{		return _out;	}		public OutputStream error()	{		return _err;	}		public char[][char[]] params()	{		return _params;	}}struct FCGX{	/**		Accept a connection and return all the relevant streams.				mapStreams = 	if true, this will replace Stdout/Stderr to output						to the FCGI streams	*/	public static int accept(out FCGI_Request req, bool mapStreams = false)	{		FCGX_Stream* _in, _out, _err;		FCGX_ParamArray _params;				int code = accept(&_in, &_out, &_err, &_params);		req = new FCGI_Request(_in, _out, _err, _params);				if(mapStreams)		{			auto layout = Stdout.layout;						Stdout = new FormatOutput!(char)(layout, req.output);			Stderr = new FormatOutput!(char)(layout, req.error);		}				return code;	}		/**		Wrapper for FCGX_Accept.	*/		public static int accept(		FCGX_Stream** stdin,		FCGX_Stream** stdout,		FCGX_Stream** stderr,		FCGX_ParamArray* envp	)	{		return FCGX_Accept(stdin, stdout, stderr, envp);	}}