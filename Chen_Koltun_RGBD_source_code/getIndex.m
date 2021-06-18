%get indices between st and en in the dimension of dim
function ind=getIndex(dim,st,en)
	if(numel(dim)~=numel(st)||numel(dim)~=numel(en))
		ind=[];
		return;
	end
	ind=st(1):en(1);
	for i=2:numel(dim)
		ind=repmat(ind,[1 en(i)-st(i)+1])+reshape(repmat(st(i)-1:en(i)-1,[numel(ind) 1]),1,[])*prod(dim(1:i-1));		
	end
end
