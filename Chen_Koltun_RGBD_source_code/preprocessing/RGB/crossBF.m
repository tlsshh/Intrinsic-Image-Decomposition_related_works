function out=crossBF(im)
	[m n d]=size(im);
	R=NRGBMap(im);
	B=mean(im,3);
	win=10;
	w=zeros(m,n,(win*2+1)^2);
	value=zeros(m,n,3,(win*2+1)^2);
	cur=0;
	h=win;
	hh=0.3;
	for i=-win:win
		for j=-win:win
			ind=getIndex([m n],[1+max(-i,0) 1+max(-j,0)],[m-max(i,0) n-max(j,0)]);
			ind2=ind+i+j*m;
			value(cur*m*n*3+[ind ind+m*n ind+m*n*2])=R([ind2 ind2+m*n ind2+m*n*2]);
			w(cur*m*n+ind)=exp(-(i*i+j*j)/h^2)*exp(-((im(ind)-im(ind2)).^2+(im(ind+m*n)-im(ind2+m*n)).^2+(im(ind+m*n*2)-im(ind2+m*n*2)).^2)/hh^2).*B(ind2);
			cur=cur+1;
		end
	end
%	if(matlabpool('size')==0)
%		matlabpool open 3;
%	end
	for i=1:m
		i
		for j=1:n
			for k=1:3
				R(i,j,k)=weightedMedian(value(i,j,k,:),w(i,j,:));
			end
		end
	end

	R=R./repmat(sum(R,3),[1 1 3]);
	out=min(max(R.*B(:,:,[1 1 1])*3,0),1);
end
