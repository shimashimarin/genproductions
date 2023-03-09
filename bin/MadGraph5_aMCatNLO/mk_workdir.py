#!/usr/bin/env python3
import argparse
from pathlib import Path


parser = argparse.ArgumentParser(description="Setup working directory for Madgraph NLO")
parser.add_argument('-i', '--input', type=str, help='Folder of the input, e.g., the unpacked gridpack folder',default=None)
parser.add_argument('-o', '--output', type=str, help='Folder of the output, e.g., work directory',default='workdir')
args = parser.parse_args()

if __name__ == '__main__':
    if args.input == None:
        print("[ mk_workdir.py ] Please set the path to the gridpack")
        exit(1)
    
    dir_gridpack = Path(args.input)
    dir_work = Path(args.output)
    dir_work.mkdir()
    print('Link:', str(dir_gridpack), "to:", str(dir_work))
    # get list of the files and directories
    recursive_gp = dir_gridpack.rglob('*')
    relative_path = []
    for p in recursive_gp:
        tmp_path = str(p).replace(str(dir_gridpack),'')
        relative_path.append(tmp_path.lstrip('/'))
    
    # sort the list to make sure shallower directories in front
    relative_path.sort(key=lambda x: x.count('/'),reverse=False)
    
    # link files
    for p in relative_path:
        if (dir_gridpack/p).is_dir():
            (dir_work/p).mkdir()
        else:
            (dir_work/p).symlink_to(dir_gridpack/p)
