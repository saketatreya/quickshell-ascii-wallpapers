import { deflateSync } from 'node:zlib';

const table = Uint32Array.from({length:256},(_,n)=>{
    for(let k=0;k<8;k++) n=(n&1)?0xedb88320^(n>>>1):n>>>1;
    return n>>>0;
});
function chunk(type,data) {
    const body=Buffer.concat([Buffer.from(type),data]);
    let crc=0xffffffff;
    for(const b of body) crc=table[(crc^b)&255]^(crc>>>8);
    const result=Buffer.alloc(body.length+8);
    result.writeUInt32BE(data.length,0);
    body.copy(result,4);
    result.writeUInt32BE((crc^0xffffffff)>>>0,result.length-4);
    return result;
}
export function png(width,height,rgba) {
    if(rgba.length!==width*height*4) throw new Error('Incorrect pixel buffer size');
    const header=Buffer.alloc(13);
    header.writeUInt32BE(width,0);header.writeUInt32BE(height,4);
    header[8]=8;header[9]=6;
    const rows=Buffer.alloc((width*4+1)*height);
    for(let y=0;y<height;y++) Buffer.from(rgba.buffer,rgba.byteOffset+y*width*4,width*4).copy(rows,y*(width*4+1)+1);
    return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',deflateSync(rows,{level:1})),chunk('IEND',Buffer.alloc(0))]);
}
export const dataUrl=(width,height,rgba)=>'data:image/png;base64,'+png(width,height,rgba).toString('base64');
