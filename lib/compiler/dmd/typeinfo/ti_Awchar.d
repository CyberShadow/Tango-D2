
module typeinfo.ti_Awchar;

private import tango.stdc.string;

// wchar[]

class TypeInfo_Au : TypeInfo
{
    char[] toUtf8() { return "wchar[]"; }

    hash_t getHash(void *p)
    {	wchar[] s = *cast(wchar[]*)p;
	size_t len = s.length;
	wchar *str = s.ptr;
	hash_t hash = 0;

	while (1)
	{
	    switch (len)
	    {
		case 0:
		    return hash;

		case 1:
		    hash *= 9;
		    hash += *cast(wchar *)str;
		    return hash;

		default:
		    hash *= 9;
		    hash += *cast(uint *)str;
		    str += 2;
		    len -= 2;
		    break;
	    }
	}

	return hash;
    }

    int equals(void *p1, void *p2)
    {
	wchar[] s1 = *cast(wchar[]*)p1;
	wchar[] s2 = *cast(wchar[]*)p2;

	return s1.length == s2.length &&
	       memcmp(cast(void *)s1, cast(void *)s2, s1.length * wchar.sizeof) == 0;
    }

    int compare(void *p1, void *p2)
    {
	wchar[] s1 = *cast(wchar[]*)p1;
	wchar[] s2 = *cast(wchar[]*)p2;
	size_t len = s1.length;

	if (s2.length < len)
	    len = s2.length;
	for (size_t u = 0; u < len; u++)
	{
	    int result = s1[u] - s2[u];
	    if (result)
		return result;
	}
	return cast(int)s1.length - cast(int)s2.length;
    }

    size_t tsize()
    {
	return (wchar[]).sizeof;
    }
}

