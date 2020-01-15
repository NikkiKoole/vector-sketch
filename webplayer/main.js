const app = new PIXI.Application({backgroundColor:0x000000, width: 1024, height: 768});
var root ;
var dragging = false;
var lastPos = undefined;

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
    app.stage.hitArea = app.screen;
    app.stage.interactive = true;
    app.stage.on('mousedown', (d)=> {
        dragging = true;
        lastPos = {x:d.data.global.x, y:d.data.global.y};
    })
    document.onmouseup = ()=> {
        dragging = false;
    }
    app.stage.on('mouseup', ()=> {
        dragging = false;
    })
    app.stage.on('mousemove', (d)=> {
        if (dragging) {
            let delta = {x: d.data.global.x - lastPos.x,y: d.data.global.y - lastPos.y}
            root.x += delta.x
            root.y += delta.y
            lastPos = {x:d.data.global.x, y:d.data.global.y};
        }
    });
    app.view.onwheel = function(d) {
        let scale = root.scale.x;
        if (d.deltaY > 0) {
            root.scale = {x:scale*0.9, y:scale*0.9}
        }else {
            root.scale = {x:scale*1.1, y:scale*1.1}
        }
        let x = (root.x - d.offsetX) * (root.scale.x/scale) + d.offsetX
        let y = (root.y - d.offsetY) * (root.scale.y/scale) + d.offsetY
        root.x = x
        root.y = y

    }
    resetAndLoadJSON('bootje.polygons.txt.json')
    app.stage.addChild(root)
}

function buildStuff(node, container) {
    node.forEach(d => {
        if (d.points) {
            container.addChild(buildShape(d));
        }
        if (d.children) {
            let parent = new PIXI.Container()
            parent.name = d.name;
            parent.x = d.transforms.l[0];
            parent.y = d.transforms.l[1];
            parent.scale = {x:d.transforms.l[3], y:d.transforms.l[4]};
            parent.pivot = {x:d.transforms.l[5], y:d.transforms.l[6]}
            parent.rotation = d.transforms.l[2];
            buildStuff(d.children, parent);
            container.addChild(parent);
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
    if (shape.hole) {
	console.log('hole yeah!')
    }
   
    
    g.name = shape.name
    g.drawPolygon(points)
    return g;
}

