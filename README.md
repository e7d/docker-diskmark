# docker-diskmark

A [fio](https://github.com/axboe/fio)-based disk benchmark [docker container](https://hub.docker.com/r/e7db/diskmark), similar to what [CrystalDiskMark](https://crystalmark.info/en/software/crystaldiskmark/) does.  
Inspired by the [crystal-disk-mark-fio-bench.sh](https://gist.github.com/0x0I/35a3aa0f810acfddeddb7ff59c37f484) GitHub Gist by [0x0I](https://gist.github.com/0x0I).  

## Basic Usage

```
docker run -it --rm e7db/diskmark
```

![Docker DiskMark](https://github.com/e7d/docker-diskmark/raw/main/assets/diskmark.png?raw=true "Docker DiskMark")

## Profiles

The container contains two different test profiles:
- Default profile:
  - Sequential 1M Q8T1
  - Sequential 1M Q1T1
  - Random 4K Q32T1
  - Random 4K Q1T1
- NVMe profile:
  - Sequential 1M Q8T1
  - Sequential 128K Q32T1
  - Random 4K Q32T16
  - Random 4K Q1T1

## Advanced usage

Find below a table listing all the different parameters you can use with the container:
| Parameter            | Type        | Default | Description |
| :-                   | :-          |:-       | :- |
| `PROFILE`            | Environment | auto    | The disk profile to apply:<br>- `auto` to try and autoselect the best one,<br>- `default`, best suited for "traditional" disks,<br>- `nvme`, best suited for NMVe SSD disks. |
| `DATA`               | Environment | random  | The test data:<br>- `random` to use random data,<br>- `0x00` to fill with 0 (zero) values. |
| `SIZE`               | Environment | 1G      | The size of the test file in bytes. |
| `LOOPS`              | Environment | 5       | The number of test loops. |
| `/disk`              | Volume      |         | The target path to benchmark. |

By default, a 1 GB test file is used, using 5 loops for each test, reading and writing random bytes on the disk where Docker is installed.

### With parameters

For example, you could go and use a 4 GB file looping each test twice, and writting only zeros instead of random data.  
You can achieve this using the following command:  
```
docker run -it --rm -e SIZE=4G -e LOOPS=2 -e DATA=0x00 e7db/diskmark
```

### Force profile

A detection of your disk is made, so the benchmark uses the appropriate profile, `default` or `default`.  
In the event that the detection returns a wrong value, you can force the use of either of the profiles:  
```
docker run -it --rm -e PROFILE=default e7db/diskmark
```

### Specific disk

By default, the benchmark runs on the disk where Docker is installed, using a [Docker volume](https://docs.docker.com/storage/volumes/) mounted on the `/disk` path inside the container.  
To run the benchmark on a different disk, use a path belonging to that disk, and mount it as the `/disk` volume:  
```
docker run -it --rm -v /path/to/specific/disk:/disk e7db/diskmark
```
