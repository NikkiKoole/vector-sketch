const app = new PIXI.Application({backgroundColor:0x000000, width: 1024, height: 768});
var root ;

function dropHandler(ev) {
    ev.preventDefault();

    if (ev.dataTransfer.items) {
        for (var i = 0; i < ev.dataTransfer.items.length; i++) {
            if (ev.dataTransfer.items[i].kind === 'file') {
                var file = ev.dataTransfer.items[i].getAsFile();
                if (file.name.endsWith('.txt.json')) {
                    resetAndLoadJSON(file.name);
                }
            }
        }
    } 
}

function dragOverHandler(ev) {
    // Prevent default behavior (Prevent file from being opened)a
    ev.preventDefault();
}


const loadJSON = (url, callback) => {
    let xobj = new XMLHttpRequest();
    xobj.overrideMimeType("application/json");
    xobj.open('GET', url, true);
    xobj.onreadystatechange = () => {
        if (xobj.readyState === 4 && xobj.status === 200) {
            callback(xobj.responseText);
        }
    };
    xobj.send(null);
}

function resetAndLoadJSON(url) {
    root.removeChildren();
    loadJSON(url, (response) => {
        let json = JSON.parse(response);
        buildStuff(json, root)
    });
}



window.onload = function() {
    document.body.appendChild(app.view);
    
    root = new PIXI.Container();
    loadJSON('enfieldagain____.polygons.txt.json', (response) => {
        let json = JSON.parse(response);
        buildStuff(json, root)
    });

    app.stage.addChild(root)
}

function buildStuff(node, container) {
    node.forEach(d => {
        if (d.points) {
            let thing = buildShape(d);
            container.addChild(thing);
        }
        if (d.children) {
            let folder = new PIXI.Container()
            folder.name = d.name;
            folder.x = d.transforms.l[0];
            folder.y = d.transforms.l[1];
            folder.scale = {x:d.transforms.l[3], y:d.transforms.l[4]};
            folder.pivot = {x:d.transforms.l[5], y:d.transforms.l[6]}
            folder.rotation = d.transforms.l[2];
            buildStuff(d.children, folder);
            container.addChild(folder);
        }
    })
}

var rgbToHex = function (rgb) { 
    var hex = Number(rgb).toString(16);
    if (hex.length < 2) hex = "0" + hex;
    return hex;
};

var fullColorHex = function(r,g,b) {   
    let red = rgbToHex(Math.floor(r*255));
    let green = rgbToHex(Math.floor(g*255));
    let blue = rgbToHex(Math.floor(b*255));
    return red+green+blue;
};

function buildShape(shape) {
    let g = new PIXI.Graphics();
    let color =  '0x' + fullColorHex(shape.color[0], shape.color[1], shape.color[2]);
    g.beginFill(color, shape.color[3]);
    let points = []
    shape.points.forEach(p => {
        points.push(p[0])
        points.push(p[1])
    })
    g.name = shape.name
    g.drawPolygon(points)
    return g;
}

