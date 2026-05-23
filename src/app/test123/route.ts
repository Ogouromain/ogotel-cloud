import { NextResponse } from 'next/server';

export async function GET() {
  return new NextResponse('<html><body><h1>TEST WORKS!</h1></body></html>', {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}
