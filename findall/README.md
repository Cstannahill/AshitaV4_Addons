# FindAll

This addon searches items stored on all your characters.

The list is stored on the machine on which the addon is executed, being updated everytime
you look for an item, certain packets arrive, or you logout, so this will not work the best
if you use multiple PCs, unless you store your Ashita installation in Dropbox or somewhere.

The tracker functionality has been removed. It should be a seperate addon.

## Commands

### Update ###

```
findall
```

Forces a list update

### Search ###

```
findall [:<character1> [:...]] <query> [-e<filename>|--export=<filename>]
```
* `character1`: the name of the characters to use for the search.
* `...`: variable list of character names.
* `query` the word you are looking for.
* `-d` or `--duplicates` to list only items which are found in more than one container
* `-e<filename>` or `--export=<filename>` exports the results to a csv file. The file will be created in the data folder.
* `-s` or `--stackables` to list only items which can stack

Looks for any item whose name (long or short) contains the specified value on the specified characters.

## Examples ##

```
findall thaumas
```

Search for "thaumas" on all your characters.

```
findall :alpha :beta thaumas
```

Search for "thaumas" on "alpha" and "beta" characters.

```
findall :omega
```

Show all the items stored on "omega".

----

## TODO

----

## Changelog

### v1.20170501
* first port