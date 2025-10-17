// https://http.dev/1.1

string timeT() { return time("(%T)"); }
struct Console {
    void debug(string s) { write(timeT() + " [dbg] "+s); }
    void log  (string s) { write(timeT() + " [info] "+s); }
    void info (string s) { write(timeT() + " [info] "+s); }
    void warn (string s) { write(timeT() + " [warn] "+s); }
    void error(string s) { write(timeT() + " [error] "+s); }
}
Console console;

// i accidentally wrote contains() instead of startswith() im retarded
//bool contains(string s, string p)
//{
//    string[] s = array(s);
//    string[] p = array(p);
//    for (int i = 0; i < s.length; i++) {
//        bool result;
//        for (int j = 0; j < p.length && i+j < s.length; j++) {
//            if (s[i+j] != p[j]) { result = false; break; }
//        }
//        if (result) return result;
//    }
//}

bool startswith(string s, string p)
{
    if (length(p) > length(s)) return false;
    string[] s = array(s);
    string[] p = array(p);
    for (int j = 0; j < p.length; j+=1) {
        if (s[j] != p[j]) return false;
    }
    return true;
}

string read_entire_file(string filename) {
    file f = input(filename, check=false, comment="", mode="binary");
    if (error(f)) {
        console.error("cannot open: " + filename); 
        return "";
    }
    string content = f;
    return content;
}

struct Header {
    string key;
    string value;
    void operator init(string key, string value) {
        this.key = key;
        this.value = value;
    }
}

struct Response {
    string status;
    string version;
    Header[] headers;
    string body;
}

struct Request {
    string method;
    string path;
    // TODO: query_params;
    string version;
    Header[] headers;
    string body;
}


int write_http_response(TcpSocket socket, Response r)
{
    socket_write(socket, r.version + ' ' + r.status + '\r\n');

    for (Header h : r.headers)
        socket_write(socket, h.key + ': ' + h.value + '\r\n');
    socket_write(socket, '\r\n');

    // https://stackoverflow.com/questions/15991173/is-the-content-length-header-required-for-a-http-1-0-response lol don't care
    socket_write(socket, r.body); 

    return 0;
}

Request parse_http_request(TcpSocket socket)
{
    Request request;

    string requestbytes;
    string part;
    int bodyidx;
    // read only until body starts because i don't care
    while ((bodyidx = find(requestbytes, '\r\n\r\n')) == -1) {
        string part = socket_read(socket);
        /* print("part"); print(part); */
        /* if (part == "") { */
        /*     error = "incomplete request"; */
        /*     return request; */
        /* } */
        requestbytes += part;
    }

    string request_lines[] = split(requestbytes, '\r\n');

    string[] g = split(request_lines[0], ' ');
    request.method = g[0]; 
    request.path = g[1]; 
    request.version = g[2];

    request_lines = request_lines[1:request_lines.length-2];
    for (string header_line : request_lines) {
        string[] parts = split(header_line, ': ');
        Header h = Header(parts[0], parts[1]);
        request.headers.push(h);
    }

    // skip body.......

    return request;
}

typedef void Handler();
struct Slot {
    string method;
    string path;
    Handler handler;

    void operator init(string method, string path, Handler handler) {
        this.method = method;
        this.path = path;
        this.handler = handler;
    }
}
struct StaticFiles {
    string prefix;
    string disk_prefix;

    void operator init(string prefix, string disk_prefix = "") {
        this.prefix = prefix;
        if (disk_prefix == "") disk_prefix = prefix;
        this.disk_prefix = disk_prefix;
    }
}
struct Router {
    Slot[] routes;
    Handler not_found_handler;
    Handler[] before_request;
    Handler[] after_request;
    StaticFiles static_files;
}

// Everything is a global variable that is mutated during every request, flask-like but worse
// to make it as dumb easy to use as possible

Response response;

Request request;

void clear_state() {
    Request r; request = r;

    Response r; response = r;
    response.version = "HTTP/1.1";
    response.status = "200 OK";
    response.headers.push(Header("Server", "web.asy/0.1"));
}

Router router;

router.not_found_handler = new void() {
    response.status = "404 Not Found";
    response.headers.push(Header("Content-Type", "text/html; charset=UTF-8"));
    response.body = '<!doctype html><html><h1>Not Found</h1></html>\n';
};

void handle_static_files()
{
    string disk_prefix = router.static_files.disk_prefix;
    StaticFiles s = router.static_files;

    string file_path = s.disk_prefix + substr(request.path, length(s.prefix), length(request.path));

    string contents = read_entire_file(file_path); // this is broken idk why i dont care touch grass
    // TODO: mime types
    //response.headers.push(Header("Content-Type", "image/png"));
    //response.headers.push(Header("Content-Length", string(length(contents))));

    response.body = contents;
}


void GET(string path, Handler handler) 
{
    router.routes.push(Slot("GET", path, handler));
}

void not_found(Handler handler) 
{
    router.not_found_handler = handler;
}

void before_request(Handler handler) 
{
    router.before_request.push(handler);
}

void after_request(Handler handler) 
{
    router.after_request.push(handler);
}

void mount(string path, string prefix)
{
    router.static_files = StaticFiles(path, prefix);
}

Handler route(Router router)
{
    for (Slot s : router.routes) {
        if (s.method == request.method && s.path == request.path) return s.handler;
    }
    return router.not_found_handler;
    // TODO: 
    // method routing
    // internal server error
    // etc.
}

void html(string html) 
{
    response.headers.push(Header("Content-Type", "text/html; charset=UTF-8"));
    response.body = '<!doctype html><html>' + html + '</html>';
}

void serve(string host = "127.0.0.1", int port = 8080) 
{

    console.log("starting server at " + host + " " + string(port) + "...");

    TcpServer server = create_server(host, port);

    while (true) {
        TcpSocket socket = server_accept(server);
        // TODO: socket.addr

        clear_state();

        request = parse_http_request(socket);
        for (Handler before : router.before_request) before(); // TODO: if this returns Response, stop processing and send it; if this returns null, proceed.

        if (router.static_files != null && 
        /* FIXME: this is STRING startswith, not PATH startswith, so /static-garbage/123 is handled wrong.
            But I don't really want to bother with all this garbage */
            startswith(request.path, router.static_files.prefix)) {
            handle_static_files();
        } else {
            Handler handler = route(router);
            handler();
        }
        for (Handler after : router.after_request) after();
        write_http_response(socket, response);

        socket_close(socket);
    }
    server_close(server);
}

// Templates:
// respond(h("h1", {
//   h("p", "hello world!")
// }));
// template('
// <? for post in posts { ?> <p>{{post}}></p> <? } ?>
// ')


