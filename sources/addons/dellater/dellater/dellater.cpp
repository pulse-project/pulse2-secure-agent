/*
 * (c) 2008-2009 Mandriva, http://www.mandriva.com
 *
 * $Id$
 *
 * This file is part of Pulse 2, http://pulse2.mandriva.org
 *
 * Pulse 2 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Pulse 2 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Pulse 2; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

#include "stdafx.h"


int _tmain(int argc, _TCHAR* argv[]) {
    DWORD dw;
    LPVOID lpMsgBuf;
    int ret;

    if (argc != 2) {
        printf("Schedule a file or directory removal for the next reboot.\n");
        printf("Copyright 2008 Mandriva, Pulse 2 product, 27082008\n\n");
        printf("DELLATER <path/to/remove>\n");
        ret = 1;
    } else {
        if (MoveFileEx(argv[1], NULL, MOVEFILE_DELAY_UNTIL_REBOOT)) {
            ret = 0;
        } else {
            dw = GetLastError();
            FormatMessage(
                FORMAT_MESSAGE_ALLOCATE_BUFFER |
                FORMAT_MESSAGE_FROM_SYSTEM |
                FORMAT_MESSAGE_IGNORE_INSERTS,
                NULL,
                dw,
                MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                (LPTSTR) &lpMsgBuf,
                0, NULL );
            printf("Failed with error %d: %s\n" , dw, lpMsgBuf);
            ret = 1;
        }
    }
    return ret;
}

