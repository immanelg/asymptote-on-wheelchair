import web;

GET("/", new void() {
    html('
        <head>
            <title>Hello</title>
            <link rel="stylesheet" href="/static/style.css">
        </head>
        <body>
            <h1>Hello, World!</h1>
            <img src="/static/Go-Logo_Aqua.svg" width="500" height="500">
        </body>
    ');
});

not_found(new void() {
    response.status = "404 Not Found";
    response.headers.push(Header("Content-Type", "text/html; charset=UTF-8"));
    response.body = '<!doctype html><html><h1>This Web Page doesn\'t exists!</h1></html>\n';
});

// logger middleware
after_request(new void() {
    // web scale console.log() 🔥
    console.log(request.method + " " + request.path + " " + response.status);
});
// before_request(...)

mount("/static", "./static_files");

serve("127.0.0.1", 8080);
