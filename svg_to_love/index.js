//https://github.com/mattdesl/svg-mesh-3d/blob/master/index.js

var fs = require('fs');
var parseString = require('xml2js').parseString;
var parseSVGPath = require('parse-svg-path')
var getContours = require('svg-path-contours')
var assign = require('object-assign')
var simplify = require('simplify-path')
//var normalize = require('normalize-path-scale')
//var getBounds = require('bound-points')
var cleanPSLG = require('clean-pslg')
var cdt2d = require('cdt2d')
var hexRgb = require('hex-rgb');
var decomp = require('poly-decomp');

if (!process.argv[2] || !process.argv[2].endsWith('.svg') ) {
    console.log('give me a svg file to convert!')
    console.log('node index.js ./file.svg')
    console.log('optionally you can put a float simplify value as last')
    return
}

var url = process.argv[2]
var simplifyValue = parseFloat(process.argv[3])

fs.readFile( url, function (err, data) {
    if (err) {
        throw err; 
    }
    var xml = data.toString()
    var total = 0
    parseString(xml, function (err, result) {
        var opt = {
            delaunay: true,
            clean: true,
            exterior: false,
            randomization: 0,
            simplify: simplifyValue || 0.2,
            scale:  1,

        }

        var metaInfo = result.svg['$'];
        //console.log(metaInfo)
        var metaWidth = parseInt(metaInfo.width)
        var metaHeight = parseInt(metaInfo.height)
        var newWidth = 1200
        var newHeight = 1200

        var groups = result.svg.g;
        var groupIndex  = 0
        groups.forEach(g => {
            var gMeta = g['$']
            //console.log(gMeta, g)
            var paths = g.path
            var pathIndex = 0
            paths.forEach(p => {

                var fill = p['$'].fill
                var opacity = p['$'].opacity
                var d = p['$'].d
                var parsed = parseSVGPath(d)
                var contours = getContours(parsed, opt.scale)
		//console.log(contours)
                contours =  removeConsecutiveDuplications(contours)

		
		//contours.forEach(c => {
		//    decomp.makeCCW(c);
		//})

		
                if (opt.simplify > 0 && typeof opt.simplify === 'number') {
                    for (i = 0; i < contours.length; i++) {
                        contours[i] = simplify(contours[i], opt.simplify)
                    }
                }
		// for (i=0; i<contours.length;i++) {
		//     //console.log('durp', contours[i])
		    
		//     console.log('before ', JSON.stringify(contours[i]))
		//     console.log(i, decomp.isSimple(contours[i]))
		//     decomp.makeCCW(contours[i]);
		//     var convexPolygons = decomp.quickDecomp(contours[i]);
		//     console.log(convexPolygons)
		//     //contours[i] = decomp.quickDecomp(contours[i]);
		//     console.log('after ', JSON.stringify(contours[i]))

		// }
                //contours = normalizeContours(contours, metaWidth, metaHeight, newWidth, newHeight)
		//console.log(contours)
		//decomp.decomp(contours);
		//decomp.makeCCW(contours)
		var cCount = 0
		contours.forEach(c => {
		    cCount += c.length
		})
		
		 var polyline = denestPolyline(contours)
                 var loops = polyline.edges
                 var positions = polyline.positions
                 var edges = []
                 for (i = 0; i < loops.length; ++i) {
                     var loop = loops[i]
                     for (var j = 0; j < loop.length; ++j) {
                         edges.push([loop[j], loop[(j + 1) % loop.length]])
                     }
                 }
                
                // // this updates points/edges so that they now form a valid PSLG 
                 if (opt.clean !== false) {
                    cleanPSLG(positions, edges)
                 }
		//var str = makeLoveShapePositions(fill, opacity, positions, groupIndex, pathIndex)
		//console.log("POSITION OUTPUT: ", str)
		var str = makeLoveShape(fill, opacity, contours, groupIndex, pathIndex)
		console.log(str)
		
                //console.log(positions.length, cCount)
                // // triangulation
                 var cells = cdt2d(positions, edges, opt)
                 total += cells.length
                pathIndex += 1
               
            })
            groupIndex += 1
        })
	//console.log("toal cells: ", total)
    });
    

});

function normalizeContours(contours, width, height, newWidth, newHeight) {
    var result = []
   
    contours.forEach(c => {
        var newContour = []
        c.forEach( point => {
            newContour.push([(point[0]/width)*newWidth, (point[1]/height) * newHeight])
        })
        result.push(newContour)
    })
    return result;
}

function toFixed(n) {
    return  Number.parseFloat(n).toFixed(2)
}

function makeLoveShapePositions(fill, opacity, contours, groupIndex, pathIndex) {

    let totalResult = ""
    let rgb = hexRgb(fill)
    let contourIndex = 0
    let first = contours[0]
    let points = "{"
    let color = `{${toFixed(rgb.red/255)},${toFixed(rgb.green/255)},${toFixed(rgb.blue/255)},${opacity}}`
    for (let j =0; j< contours.length; j++) {
	let p = contours[j]
	points += `{${toFixed(p[0])},${toFixed(p[1])}}, `
    }
    points += "}";
    let result =
`{
name="${groupIndex+'-'+pathIndex+'-'+contourIndex}",
color=${color},
points=${points}
},
`
    contourIndex += 1
    totalResult += result
    return totalResult
}


function makeLoveShape(fill, opacity, contours, groupIndex, pathIndex) {
    let totalResult = ""
    let rgb = hexRgb(fill)
    // a single path can become many many contours
    // each contour needs to become its own shape
    let contourIndex = 0
    contours.forEach(c => {
	
        let color = `{${toFixed(rgb.red/255)},${toFixed(rgb.green/255)},${toFixed(rgb.blue/255)},${opacity}}`
        let points = "{"
        let first = c[0]
        for (let i = 0; i < c.length; i++) {
            let p = c[i];
            if (i == c.length - 1) {
                if (p[0] == first[0] && p[1] == first[1]) {
                } else {
                    points += `{${toFixed(p[0])},${toFixed(p[1])}}`
                }
            } else {
                points += `{${toFixed(p[0])},${toFixed(p[1])}}`
            }
            if (i < c.length -1) {
                 points += ', '
            }
        }
        
        points += '}'
        let result =
`{
name="${groupIndex+'-'+pathIndex+'-'+contourIndex}",
color=${color},
points=${points}
},
`
        //console.log(result)
        contourIndex += 1
        totalResult += result
    })
    return totalResult
}

function removeConsecutiveDuplications(contours) {
    var result = []
    contours.forEach(c => {
        var arr = [];
        var last = undefined
        c.forEach(inner => {
            if (last == undefined || (last[0] != inner[0] || last[1] != inner[1])) {
                arr.push(inner)
            }
            last = inner
        })
        result.push(arr)
    })
    
    return result
}

function denestPolyline (nested) {
  var positions = []
  var edges = []

  for (var i = 0; i < nested.length; i++) {
    var path = nested[i]
    var loop = []
    for (var j = 0; j < path.length; j++) {
      var pos = path[j]
      var idx = positions.indexOf(pos)
      if (idx === -1) {
        positions.push(pos)
        idx = positions.length - 1
      }
      loop.push(idx)
    }
    edges.push(loop)
  }
  return {
    positions: positions,
    edges: edges
  }
}
